#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Cliente asíncrono de Action Cable para comunicación serial con báscula e impresora.
Usa websockets directamente para mayor estabilidad.
"""
import sys
import os
import argparse
import asyncio
import threading
import time
import json
import serial
import serial.tools.list_ports
from datetime import datetime
import logging
import uuid
import websockets
import base64
import glob

# Import platform-specific modules conditionally
if sys.platform.startswith('win'):
    try:
        import winreg
    except ImportError:
        winreg = None

# --- Constantes ---
CONFIG_FILE = 'serial_config.json'

# --- Verificación de Plataforma (win32) ---
try:
    import win32print
    WIN32_AVAILABLE = True
    print("✓ win32print disponible")
except ImportError:
    WIN32_AVAILABLE = False
    print("✗ win32print no disponible. La impresión no funcionará.")

# --- Configuración de Logging ---
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# --- Clases de Gestión de Hardware ---

class ScaleManager:
    def __init__(self, port='COM3', baudrate=115200):
        self.port = port
        self.baudrate = baudrate
        self.serial_connection = None
        self.connected = False
        self.lock = threading.Lock()

    def set_port(self, new_port):
        with self.lock:
            if self.port != new_port:
                logger.info(f"Cambiando puerto de la báscula a: {new_port}")
                self.port = new_port
                self.disconnect()

    def connect(self) -> bool:
        with self.lock:
            if self.connected:
                return True
            try:
                # Verificar si el puerto existe antes de intentar conectarse
                available_ports = [p.device for p in serial.tools.list_ports.comports()]
                if self.port not in available_ports:
                    logger.warning(f"⚠ Puerto {self.port} no disponible en este sistema")
                    self.connected = False
                    return False

                self.serial_connection = serial.Serial(self.port, self.baudrate, timeout=1)
                self.connected = self.serial_connection.is_open
                if self.connected:
                    logger.info(f"✅ Conexión de báscula establecida en {self.port}")
                return self.connected
            except serial.SerialException as e:
                logger.error(f"✗ Error de conexión serial en báscula: {e}")
                self.connected = False
                return False
            except Exception as e:
                logger.error(f"✗ Error inesperado al conectar báscula: {e}")
                self.connected = False
                return False

    def disconnect(self):
        with self.lock:
            if self.serial_connection and self.serial_connection.is_open:
                self.serial_connection.close()
            self.connected = False
            logger.info("Báscula desconectada.")

    def read_weight(self, timeout=1):
        if not self.connect():
            return None
        try:
            with self.lock:
                start_time = time.time()
                while time.time() - start_time < timeout:
                    if self.serial_connection and self.serial_connection.in_waiting > 0:
                        data = self.serial_connection.readline().decode('utf-8').strip()
                        if data:
                            return {'weight': data, 'timestamp': datetime.now().isoformat()}
                    time.sleep(0.05)
        except serial.SerialException as e:
            logger.error(f"Error leyendo la báscula, desconectando: {e}")
            self.disconnect()
        return None

class PrinterManager:
    def __init__(self, printer_name=None):
        self.printer_name = printer_name
        self.is_connected = False
        self.lock = threading.Lock()
        self.connect_printer()

    def set_printer(self, new_printer_name):
        with self.lock:
            if self.printer_name != new_printer_name:
                logger.info(f"Cambiando impresora a: {new_printer_name}")
                self.printer_name = new_printer_name
                self.connect_printer()

    def connect_printer(self):
        with self.lock:
            if not WIN32_AVAILABLE:
                self.is_connected = False
                return False
            if not self.printer_name:
                self.is_connected = False
                logger.warning("No se ha especificado un nombre de impresora.")
                return False
            try:
                printers = [p[2] for p in win32print.EnumPrinters(win32print.PRINTER_ENUM_LOCAL | win32print.PRINTER_ENUM_CONNECTIONS)]
                if self.printer_name in printers:
                    self.is_connected = True
                    logger.info(f"✅ Impresora lista: {self.printer_name}")
                else:
                    self.is_connected = False
                    logger.error(f"✗ No se encontró la impresora llamada: {self.printer_name}")
                return self.is_connected
            except Exception as e:
                logger.error(f"✗ Error buscando impresora: {e}")
                self.is_connected = False
                return False

    def print_label(self, content, ancho_mm=80, alto_mm=50):
        if not self.connect_printer():
            logger.error("Impresora no conectada.")
            return
        try:
            hPrinter = win32print.OpenPrinter(self.printer_name)
            full_content = content
            if "SIZE" not in content.upper():
                 full_content = f"SIZE {ancho_mm} mm, {alto_mm} mm\nCLS\n{content}\nPRINT 1\n"
            hJob = win32print.StartDocPrinter(hPrinter, 1, ("Label", None, "RAW"))
            win32print.StartPagePrinter(hPrinter)
            win32print.WritePrinter(hPrinter, full_content.encode('utf-8'))
            win32print.EndPagePrinter(hPrinter)
            win32print.EndDocPrinter(hJob)
            win32print.ClosePrinter(hPrinter)
            logger.info("✓ Etiqueta enviada a la impresora.")
        except Exception as e:
            logger.error(f"✗ Error al imprimir: {e}")


# --- Lógica de Configuración y Tareas Asíncronas ---

def save_config(config):
    try:
        with open(CONFIG_FILE, 'w') as f:
            json.dump(config, f, indent=4)
        logger.info(f"Configuración guardada en {CONFIG_FILE}")
    except Exception as e:
        logger.error(f"No se pudo guardar la configuración: {e}")

def load_config():
    if os.path.exists(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, 'r') as f:
                return json.load(f)
        except Exception as e:
            logger.error(f"No se pudo cargar la configuración: {e}")
    return {}

class SerialClient:
    def __init__(self, url, token, device_id, scale_manager, printer_manager):
        self.url = url
        self.token = token
        self.device_id = device_id
        self.scale_manager = scale_manager
        self.printer_manager = printer_manager
        self.websocket = None
        self.subscription_confirmed = False
        self.identifier_str = None  # Almacenar el identificador exacto usado para la suscripción
        self.message_handlers = {}
        
    async def connect(self):
        """Conectar al servidor de ActionCable"""
        try:
            # Agregar token a la URL
            full_url = f"{self.url}?token={self.token}"
            logger.info(f"Conectando a {full_url}")

            self.websocket = await websockets.connect(full_url)
            logger.info("Conexión WebSocket establecida")

            # Enviar mensaje de suscripción - usar el mismo formato que en los mensajes posteriores
            channel_identifier = {'channel': 'SerialConnectionChannel', 'device_id': self.device_id}
            # Asegurar que el identificador tenga el mismo formato que se usará en mensajes posteriores
            self.identifier_str = json.dumps(channel_identifier, separators=(',', ':'))
            subscribe_msg = {
                'command': 'subscribe',
                'identifier': self.identifier_str
            }
            await self.websocket.send(json.dumps(subscribe_msg, separators=(',', ':')))
            logger.info(f"Suscribiendo al canal: {channel_identifier}")

            return True
        except Exception as e:
            logger.error(f"Error conectando al servidor: {e}")
            return False

    async def send_data(self, action, data):
        """Enviar datos al servidor"""
        # Esperar a que la suscripción esté confirmada antes de enviar datos
        if not self.subscription_confirmed:
            logger.debug("Esperando confirmación de suscripción antes de enviar datos...")
            # Esperar brevemente para permitir que se confirme la suscripción
            await asyncio.sleep(1)

        if self.websocket and self.subscription_confirmed and self.identifier_str:
            try:
                # Usar el identificador exacto que se usó para la suscripción
                msg = {
                    'command': 'message',
                    'identifier': self.identifier_str,
                    'data': json.dumps({'action': action, **data}, separators=(',', ':'))
                }
                await self.websocket.send(json.dumps(msg, separators=(',', ':')))
            except Exception as e:
                logger.error(f"Error enviando datos: {e}")

    async def listen_for_messages(self):
        """Escuchar mensajes del servidor"""
        try:
            async for message in self.websocket:
                try:
                    data = json.loads(message)

                    # Verificar si es una confirmación de suscripción
                    if data.get('type') == 'confirm_subscription' or (data.get('type') == 'welcome' and not self.subscription_confirmed):
                        logger.info("Confirmación de suscripción recibida")
                        self.subscription_confirmed = True

                    # Verificar si es un mensaje del canal
                    elif data.get('identifier') and data.get('message'):
                        identifier = json.loads(data['identifier'])
                        if identifier.get('channel') == 'SerialConnectionChannel' and identifier.get('device_id') == self.device_id:
                            await self.handle_message(data['message'])

                except json.JSONDecodeError:
                    logger.error(f"No se pudo parsear el mensaje JSON: {message}")
                except Exception as e:
                    logger.error(f"Error procesando mensaje: {e}")
        except websockets.exceptions.ConnectionClosed:
            logger.warning("Conexión WebSocket cerrada")
        except Exception as e:
            logger.error(f"Error en la escucha de mensajes: {e}")

    async def handle_message(self, message):
        """Manejar mensajes entrantes"""
        logger.info(f"Mensaje recibido: {message}")
        action = message.get('action')
        if action == 'set_config':
            logger.info("Comando de configuración recibido.")
            if message.get('scale_port'):
                self.scale_manager.set_port(message['scale_port'])
            if message.get('printer_port'):
                self.printer_manager.set_printer(message['printer_port'])
            save_config({
                'scale_port': self.scale_manager.port,
                'printer_port': self.printer_manager.printer_name
            })
        elif action == 'connect_scale':
            port = message.get('port', 'COM3')
            baudrate = message.get('baudrate', 115200)
            logger.info(f"Comando de conexión de báscula recibido: {port}, {baudrate}")
            self.scale_manager.set_port(port)
            self.scale_manager.baudrate = baudrate
            # Intentar conectar
            self.scale_manager.connect()
        elif action == 'disconnect_scale':
            logger.info("Comando de desconexión de báscula recibido.")
            self.scale_manager.disconnect()
        elif action == 'start_scale_reading':
            logger.info("Comando de inicio de lectura de báscula recibido.")
            # Ya se está realizando lectura periódica en stream_updates
        elif action == 'stop_scale_reading':
            logger.info("Comando de detención de lectura de báscula recibido.")
            # La lectura se detiene cuando se cierra la conexión
        elif action == 'connect_printer':
            logger.info("Comando de conexión de impresora recibido.")
            # La conexión de impresora se gestiona internamente
            self.printer_manager.connect_printer()
        elif action == 'disconnect_printer':
            logger.info("Comando de desconexión de impresora recibido.")
            # No hay una desconexión explícita de impresora en el manager
            self.printer_manager.is_connected = False
        elif action == 'print_label':
            content = message.get('content', '')
            ancho_mm = message.get('ancho_mm', 80)
            alto_mm = message.get('alto_mm', 50)
            logger.info(f"Comando de impresión recibido: {content[:50]}...")
            self.printer_manager.print_label(content, ancho_mm=ancho_mm, alto_mm=alto_mm)
        elif action == 'test_printer':
            ancho_mm = message.get('ancho_mm', 80)
            alto_mm = message.get('alto_mm', 50)
            logger.info(f"Comando de prueba de impresora recibido: {ancho_mm}x{alto_mm}mm")
            # Enviar contenido de prueba
            test_content = f"SIZE {ancho_mm} mm, {alto_mm} mm\nCLS\nTEST LABEL\nPRINT 1\n"
            self.printer_manager.print_label(test_content, ancho_mm=ancho_mm, alto_mm=alto_mm)
        elif action == 'ping':
            # Enviar respuesta de pong para confirmar la conexión
            await self.send_data('receive', {
                'action': 'pong',
                'timestamp': datetime.now().isoformat()
            })

    async def close(self):
        """Cerrar la conexión"""
        if self.websocket:
            await self.websocket.close()


async def stream_updates(client, scale_manager, printer_manager, device_id):
    """Enviar actualizaciones periódicas al servidor"""
    logger.info("Stream de actualizaciones iniciado.")

    # Variables para almacenar el estado anterior y evitar enviar actualizaciones innecesarias
    previous_ports = []
    previous_scale_status = None
    previous_printer_status = None

    # Esperar un poco para asegurar que la conexión esté completamente establecida
    await asyncio.sleep(2)

    # Enviar la lista de puertos inmediatamente al iniciar
    try:
        # Asegurarse de esperar a que la suscripción esté confirmada antes de enviar
        max_attempts = 30  # Aumentar aún más el número de intentos
        attempt = 0
        while not client.subscription_confirmed and attempt < max_attempts:
            logger.info(f"Esperando confirmación de suscripción... (intento {attempt + 1}/{max_attempts})")
            await asyncio.sleep(0.5)
            attempt += 1

        if not client.subscription_confirmed:
            logger.warning("No se pudo confirmar la suscripción después de varios intentos")
            return  # Salir si no se confirma la suscripción

        logger.info("La suscripción ha sido confirmada, obteniendo lista de puertos...")

        # Obtener puertos serie reales después de confirmar la suscripción
        ports = await asyncio.to_thread(serial.tools.list_ports.comports)
        port_list = [{'device': p.device, 'description': p.description} for p in ports]
        logger.info(f"Puertos serie detectados: {len(ports)}")
        for p in ports:
            logger.info(f"  - {p.device}: {p.description}")

        # En sistemas Unix/Linux, también incluir puertos virtuales como /dev/pts/*
        if sys.platform.startswith('linux') or sys.platform.startswith('darwin'):
            import glob
            # Agregar puertos virtuales de Linux (como los de USB serial adapters)
            virtual_ports = glob.glob('/dev/tty[A-Za-z]*')  # /dev/ttyS*, /dev/ttyUSB*, /dev/ttyACM*, etc.
            virtual_ports.extend(glob.glob('/dev/pts/*'))  # Puertos virtuales tipo terminal pseudo
            logger.info(f"Puertos virtuales encontrados: {len(virtual_ports)}")
            for vp in virtual_ports:
                if vp not in [p['device'] for p in port_list]:  # Evitar duplicados
                    port_list.append({'device': vp, 'description': f'Puerto virtual {vp.split("/")[-1]}'})
                    logger.info(f"Añadido puerto virtual: {vp}")

        # En Windows, buscar puertos adicionales
        if sys.platform.startswith('win'):
            import winreg
            try:
                # Buscar puertos Bluetooth y otros puertos virtuales en Windows
                key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"HARDWARE\DEVICEMAP\SERIALCOMM")
                i = 0
                while True:
                    try:
                        name, value, _ = winreg.EnumValue(key, i)
                        if value not in [p['device'] for p in port_list]:
                            port_list.append({'device': value, 'description': f'Puerto virtual {value}'})
                            logger.info(f"Añadido puerto virtual Windows: {value}")
                        i += 1
                    except WindowsError:
                        break
                winreg.CloseKey(key)
            except Exception as reg_error:
                logger.info(f"No se pudieron leer puertos virtuales desde el registro: {reg_error}")

        # Detectar impresoras si están disponibles
        if WIN32_AVAILABLE:
            try:
                printers = await asyncio.to_thread(win32print.EnumPrinters, win32print.PRINTER_ENUM_LOCAL | win32print.PRINTER_ENUM_CONNECTIONS)
                for p in printers:
                    port_list.append({'device': p[2], 'description': f'Impresora: {p[2]}'})
                    logger.info(f"Añadida impresora: {p[2]}")
            except Exception as printer_error:
                logger.warning(f"Error obteniendo impresoras: {printer_error}")
        else:
            # En sistemas no Windows, intentar detectar impresoras de forma diferente
            logger.info("Sistema no Windows, detectando posibles impresoras...")
            # En macOS/Linux, podríamos intentar detectar impresoras de otras formas
            # Por ahora, solo agregamos la impresora configurada si existe
            if printer_manager.printer_name:
                port_list.append({'device': printer_manager.printer_name, 'description': f'Impresora: {printer_manager.printer_name}'})
                logger.info(f"Añadida impresora configurada: {printer_manager.printer_name}")

        logger.info(f"Total de puertos detectados: {len(port_list)}")

        if client.subscription_confirmed:
            logger.info("Enviando mensaje de actualización de puertos...")
            await client.send_data('receive', {
                'action': 'ports_update',
                'ports': port_list,
                'scale_port': scale_manager.port,
                'scale_connected': scale_manager.connected,
                'printer_port': printer_manager.printer_name,
                'printer_connected': printer_manager.is_connected
            })
            logger.info(f"Mensaje de puertos enviado: {len(port_list)} puertos")

            # Registrar explícitamente qué datos se están enviando
            logger.info(f"Datos enviados - Scale port: {scale_manager.port}, Scale connected: {scale_manager.connected}")
            logger.info(f"Datos enviados - Printer port: {printer_manager.printer_name}, Printer connected: {printer_manager.is_connected}")
        else:
            logger.warning("No se pudo confirmar la suscripción después de varios intentos")

        # Actualizar valores anteriores
        previous_ports = port_list.copy()  # Create a copy to avoid reference issues
        previous_scale_status = scale_manager.connected
        previous_printer_status = printer_manager.is_connected

        logger.info(f"Lista inicial de puertos enviada: {len(port_list)} dispositivos encontrados")
        for port in port_list:
            logger.info(f"  - {port['device']}: {port['description']}")
    except Exception as e:
        logger.error(f"Error al enviar la lista inicial de puertos: {e}")
        logger.error(f"Error details: {str(e)}", exc_info=True)
        # Asegurarse de que se envíe al menos un mensaje vacío para actualizar la UI
        try:
            if client.subscription_confirmed:
                logger.info("Enviando mensaje de puertos vacío debido al error...")
                await client.send_data('receive', {
                    'action': 'ports_update',
                    'ports': [],
                    'scale_port': scale_manager.port,
                    'scale_connected': scale_manager.connected,
                    'printer_port': printer_manager.printer_name,
                    'printer_connected': printer_manager.is_connected
                })
        except Exception as send_error:
            logger.error(f"Error al enviar mensaje de puertos vacío: {send_error}")

    while True:
        try:
            # Obtener puertos disponibles (misma lógica que arriba)
            ports = await asyncio.to_thread(serial.tools.list_ports.comports)
            port_list = [{'device': p.device, 'description': p.description} for p in ports]

            # En sistemas Unix/Linux, también incluir puertos virtuales como /dev/pts/*
            if sys.platform.startswith('linux') or sys.platform.startswith('darwin'):
                import glob
                # Agregar puertos virtuales de Linux (como los de USB serial adapters)
                virtual_ports = glob.glob('/dev/tty[A-Za-z]*')  # /dev/ttyS*, /dev/ttyUSB*, /dev/ttyACM*, etc.
                virtual_ports.extend(glob.glob('/dev/pts/*'))  # Puertos virtuales tipo terminal pseudo
                for vp in virtual_ports:
                    if vp not in [p['device'] for p in port_list]:  # Evitar duplicados
                        port_list.append({'device': vp, 'description': f'Puerto virtual {vp.split("/")[-1]}'})

            # En Windows, buscar puertos adicionales
            if sys.platform.startswith('win'):
                import winreg
                try:
                    # Buscar puertos Bluetooth y otros puertos virtuales en Windows
                    key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"HARDWARE\DEVICEMAP\SERIALCOMM")
                    i = 0
                    while True:
                        try:
                            name, value, _ = winreg.EnumValue(key, i)
                            if value not in [p['device'] for p in port_list]:
                                port_list.append({'device': value, 'description': f'Puerto virtual {value}'})
                            i += 1
                        except WindowsError:
                            break
                    winreg.CloseKey(key)
                except Exception as reg_error:
                    logger.info(f"No se pudieron leer puertos virtuales desde el registro: {reg_error}")

            if WIN32_AVAILABLE:
                try:
                    printers = await asyncio.to_thread(win32print.EnumPrinters, win32print.PRINTER_ENUM_LOCAL | win32print.PRINTER_ENUM_CONNECTIONS)
                    for p in printers:
                        printer_exists = any(p[2] == port['device'] for port in port_list)
                        if not printer_exists:
                            port_list.append({'device': p[2], 'description': f'Impresora: {p[2]}'})
                except Exception as printer_error:
                    logger.warning(f"Error obteniendo impresoras: {printer_error}")

            # Solo enviar actualización si hay cambios significativos
            ports_changed = len(previous_ports) != len(port_list) or \
                           any(prev != curr for prev, curr in zip(previous_ports, port_list))

            if (ports_changed or
                scale_manager.connected != previous_scale_status or
                printer_manager.is_connected != previous_printer_status):

                if client.subscription_confirmed:
                    await client.send_data('receive', {
                        'action': 'ports_update',
                        'ports': port_list,
                        'scale_port': scale_manager.port,
                        'scale_connected': scale_manager.connected,
                        'printer_port': printer_manager.printer_name,
                        'printer_connected': printer_manager.is_connected
                    })

                # Actualizar valores anteriores solo si se envió la actualización
                previous_ports = port_list.copy()
                previous_scale_status = scale_manager.connected
                previous_printer_status = printer_manager.is_connected

            # Leer peso de la báscula
            reading = await asyncio.to_thread(scale_manager.read_weight)
            if reading and client.subscription_confirmed:
                await client.send_data('receive', {
                    'action': 'weight_update',
                    'weight': reading['weight'],
                    'timestamp': reading['timestamp']
                })

            # Esperar antes de la próxima iteración - aumentar intervalo para reducir uso
            await asyncio.sleep(3)  # Reduced from 5 to 3 seconds for more responsive updates
        except Exception as e:
            logger.error(f"Error en el stream de actualizaciones: {e}")
            # Reiniciar managers en caso de error persistente
            try:
                scale_manager.disconnect()
            except:
                pass
            try:
                printer_manager.connect_printer()
            except:
                pass
            await asyncio.sleep(5)


async def main_loop(url, token, device_id, args):
    local_config = load_config()
    initial_scale_port = args.scale_port or local_config.get('scale_port') or 'COM3'
    initial_printer_port = args.printer_port or local_config.get('printer_port')

    scale_manager = ScaleManager(port=initial_scale_port)
    printer_manager = PrinterManager(printer_name=initial_printer_port)

    # Parámetros para manejo de reconexiones
    max_reconnection_delay = 60  # Máximo 60 segundos entre reconexiones
    reconnection_delay = 5      # Iniciar con 5 segundos
    backoff_factor = 1.5        # Factor de incremento exponencial

    while True:
        try:
            client = SerialClient(url, token, device_id, scale_manager, printer_manager)
            
            if await client.connect():
                logger.info("✓ Conexión y suscripción establecidas.")
                
                # Reiniciar el retraso de reconexión cuando se establece la conexión
                reconnection_delay = 5

                # Crear tareas concurrentes
                listen_task = asyncio.create_task(client.listen_for_messages())
                stream_task = asyncio.create_task(stream_updates(client, scale_manager, printer_manager, device_id))

                # Esperar a que alguna tarea termine
                done, pending = await asyncio.wait([listen_task, stream_task], return_when=asyncio.FIRST_COMPLETED)
                
                # Cancelar tareas pendientes
                for task in pending:
                    task.cancel()
                    try:
                        await task  # Esperar a que la tarea termine la cancelación
                    except:
                        pass  # Ignorar excepciones durante la cancelación

                logger.info("Tareas terminadas, cerrando conexión...")
                await client.close()
                
                logger.warning("Una de las tareas principales ha terminado, reconectando...")
            else:
                logger.error("No se pudo conectar al servidor")
                
        except Exception as e:
            logger.error(f"Error en el bucle de conexión: {type(e).__name__} - {e}")
        
        # Incrementar el retraso de reconexión con un límite máximo
        reconnection_delay = min(reconnection_delay * backoff_factor, max_reconnection_delay)
        logger.warning(f"Conexión perdida. Reintentando en {reconnection_delay:.1f} segundos...")
        await asyncio.sleep(reconnection_delay)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Cliente serial para WMSys.')
    parser.add_argument('--url', type=str, default=os.getenv('SERIAL_SERVER_URL', 'ws://localhost:3000/cable'), help='URL del servidor.')
    parser.add_argument('--token', type=str, required=True, help='Token de autenticación.')
    parser.add_argument('--device-id', type=str, help='ID único del dispositivo.')
    parser.add_argument('--scale-port', type=str, default=None, help='Puerto de la báscula.')
    parser.add_argument('--printer-port', type=str, default=None, help='Nombre de la impresora.')
    args = parser.parse_args()

    # Si no se proporciona un device-id, usar uno por defecto
    device_id = args.device_id or f"device-serial-{uuid.getnode()}"

    try:
        asyncio.run(main_loop(args.url, args.token, device_id, args))
    except KeyboardInterrupt:
        logger.info("Cliente cerrado.")