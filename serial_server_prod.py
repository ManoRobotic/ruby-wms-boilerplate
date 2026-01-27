#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Cliente asíncrono de Action Cable para comunicación serial con báscula e impresora.
Versión final completamente funcional.
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
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# --- Clases de Gestión de Hardware ---

class ScaleManager:
    def __init__(self, port=None, baudrate=115200):
        self.port = port
        self.baudrate = baudrate
        self.serial_connection = None
        self.connected = False
        self.lock = threading.RLock() # Usar RLock para permitir llamadas recursivas
        self.last_weight = 0.0

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
        self.lock = threading.RLock() # Usar RLock para permitir llamadas recursivas
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
        hPrinter = None
        try:
            hPrinter = win32print.OpenPrinter(self.printer_name)
            full_content = content
            # Si el contenido empieza con ^XA, es ZPL (Zebra) y no necesita wrappers de TSPL
            is_zpl = content.strip().startswith("^XA")

            # Only add wrapper commands if it's not ZPL and doesn't already have SIZE command
            if not is_zpl and "SIZE" not in content.upper():
                full_content = f"SIZE {ancho_mm} mm, {alto_mm} mm\nCLS\n{content}\nPRINT 1,1\n"
            else:
                # If it already has SIZE or is ZPL, make sure it ends with a newline for proper processing
                full_content = content

            # Ensure the content ends with a newline for proper processing
            if not full_content.endswith('\n'):
                full_content += '\n'

            # Send the raw data directly to the printer using the Windows API
            hJob = win32print.StartDocPrinter(hPrinter, 1, ("Label", None, "RAW"))
            win32print.StartPagePrinter(hPrinter)
            win32print.WritePrinter(hPrinter, full_content.encode('utf-8'))

            # Add a small delay to ensure the printer processes the data
            import time
            time.sleep(0.2)

            # Try to end the document properly - but handle the EndDocPrinter error gracefully
            try:
                win32print.EndPagePrinter(hPrinter)
                win32print.EndDocPrinter(hJob)
            except Exception as doc_error:
                logger.warning(f"Error con EndDocPrinter: {doc_error}. Continuando...")
                # Sometimes the data is still sent to the printer even if EndDocPrinter fails

            # Close the printer handle to ensure data is flushed
            win32print.ClosePrinter(hPrinter)

            logger.info(f"✓ Etiqueta {'ZPL' if is_zpl else 'TSPL'} enviada a la impresora.")
        except Exception as e:
            logger.error(f"✗ Error al imprimir: {e}")
            # Attempt to clean up resources in case of error
            if hPrinter:
                try:
                    win32print.ClosePrinter(hPrinter)
                except:
                    pass  # Ignore cleanup errors


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
        self.configuration_received = False
        self.identifier_str = None  # Almacenar el identificador exacto usado para la suscripción
        self.message_handlers = {}

    async def connect(self):
        """Conectar al servidor de ActionCable"""
        try:
            # Agregar token a la URL
            full_url = f"{self.url}?token={self.token}"
            logger.info(f"Conectando a {full_url}")

            try:
                # Intentar con extra_headers para saltar aviso de ngrok
                self.websocket = await websockets.connect(
                    full_url,
                    extra_headers={
                        "ngrok-skip-browser-warning": "any-value"
                    }
                )
            except TypeError as e:
                if "extra_headers" in str(e):
                    logger.warning("Tu versión de websockets es antigua y no soporta 'extra_headers'. Intentando conexión simple...")
                    self.websocket = await websockets.connect(full_url)
                else:
                    raise
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

    async def send_data(self, data):
        """Enviar datos al servidor"""
        # Ya no esperamos confirmación. Si el socket está abierto, enviamos.
        if self.websocket and self.identifier_str:
            try:
                action = data.get('action', 'unknown')
                msg = {
                    'command': 'message',
                    'identifier': self.identifier_str,
                    'data': json.dumps(data, separators=(',', ':'))
                }
                await self.websocket.send(json.dumps(msg, separators=(',', ':')))
                logger.info(f">>> Mensaje enviado a Rails: {action}")
            except Exception as e:
                logger.error(f"Error enviando datos: {e}")
        else:
            logger.debug("No se pudo enviar: socket no disponible o sin identificador")

    async def listen_for_messages(self):
        """Escuchar mensajes del servidor"""
        logger.info("Escuchando mensajes del WebSocket...")
        try:
            async for message in self.websocket:
                try:
                    logger.info(f"WebSocket RAW message: {message}")
                    data = json.loads(message)
                    
                    # Verificar si es una confirmación de suscripción
                    msg_type = data.get('type')
                    if msg_type == 'confirm_subscription':
                        logger.info("✓ Suscripción al canal CONFIRMADA - Cambiando estado a confirmado")
                        self.subscription_confirmed = True
                        # Forzar envío de puertos al confirmar, por si acaso
                        await self.send_ports_list()
                    
                    elif msg_type == 'welcome':
                        logger.info("ActionCable: Welcome/Bienvenida recibida")
                        
                    elif msg_type == 'ping':
                        pass
                        
                    # Procesar contenido: puede venir en 'message' o directamente en la raíz
                    # ActionCable envía pings con 'message' como un entero. Ignoramos esos.
                    payload = data.get('message')
                    
                    if isinstance(payload, dict) and 'action' in payload:
                        logger.info(f"Acción capturada del sobre 'message': {payload['action']}")
                        await self.handle_message(payload)
                    elif 'action' in data:
                        logger.info(f"Acción capturada en la raíz: {data['action']}")
                        await self.handle_message(data)
                    else:
                        logger.debug(f"Mensaje sin acción reconocida o es un ping: {data}")

                except json.JSONDecodeError:
                    logger.error(f"Error: No se pudo parsear el mensaje JSON: {message}")
                except Exception as e:
                    logger.error(f"Error inesperado procesando mensaje: {e}")
                    import traceback
                    logger.error(traceback.format_exc())

                await asyncio.sleep(0.01)
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
            
            # Verificar si los puertos nuevos están disponibles en el sistema
            new_scale_port = message.get('scale_port')
            new_printer_port = message.get('printer_port')
            
            if new_scale_port:
                available_ports = [p.device for p in serial.tools.list_ports.comports()]
                if new_scale_port in available_ports:
                    logger.info(f"Actualizando puerto de báscula a: {new_scale_port}")
                    self.scale_manager.set_port(new_scale_port)
                else:
                    logger.warning(f"Puerto de báscula {new_scale_port} no disponible")
            
            if new_printer_port:
                logger.info(f"Actualizando impresora a: {new_printer_port}")
                self.printer_manager.set_printer(new_printer_port)
                
            await asyncio.to_thread(save_config, {
                'scale_port': self.scale_manager.port,
                'printer_port': self.printer_manager.printer_name
            })

            # Marcar que la configuración ha sido recibida
            self.configuration_received = True

            # Enviar puertos SIEMPRE que nos pidan config o ports
            logger.info("Enviando respuesta de puertos tras configuración...")
            await self.send_ports_list()
        elif action == 'connect_scale':
            port = message.get('port')
            baudrate = message.get('baudrate', 115200)
            if not port:
                logger.warning("No se especificó puerto para conectar la báscula")
                return
            logger.info(f"Comando de conexión de báscula recibido: {port}, {baudrate}")
            
            # Verificar si el puerto está disponible antes de intentar conectar
            available_ports = [p.device for p in serial.tools.list_ports.comports()]
            if port in available_ports:
                self.scale_manager.set_port(port)
                self.scale_manager.baudrate = baudrate
                # Intentar conectar en un hilo aparte
                await asyncio.to_thread(self.scale_manager.connect)
            else:
                logger.warning(f"Puerto {port} no disponible para conexión de báscula")
        elif action == 'disconnect_scale':
            logger.info("Comando de desconexión de báscula recibido.")
            await asyncio.to_thread(self.scale_manager.disconnect)
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
            await asyncio.to_thread(self.printer_manager.print_label, content, ancho_mm=ancho_mm, alto_mm=alto_mm)
        elif action == 'test_printer':
            ancho_mm = message.get('ancho_mm', 80)
            alto_mm = message.get('alto_mm', 50)
            logger.info(f"Comando de prueba de impresora recibido: {ancho_mm}x{alto_mm}mm")
            # Enviar contenido de prueba
            test_content = f"SIZE {ancho_mm} mm, {alto_mm} mm\nCLS\nTEST LABEL\nPRINT 1\n"
            await asyncio.to_thread(self.printer_manager.print_label, test_content, ancho_mm=ancho_mm, alto_mm=alto_mm)
        elif action == 'ping' or message.get('type') == 'ping' or action == 'request_ports':
            logger.info(f"!!! Petición de estado '{action}' capturada !!!")
            logger.info("Enviando pong y lista de puertos de respuesta...")
            await self.send_data({
                'action': 'pong',
                'timestamp': datetime.now().isoformat()
            })
            await self.send_ports_list()
        else:
            logger.warning(f"Acción no reconocida en handle_message: {action}")

    async def send_ports_list(self):
        """Enviar la lista de puertos al servidor"""
        try:
            # Quitamos el sleep agresivo
            await asyncio.sleep(0.1)

            # Obtener puertos serie reales
            logger.info("--- Iniciando detección de puertos ---")
            try:
                ports = await asyncio.to_thread(serial.tools.list_ports.comports)
                port_list = [{'device': p.device, 'description': p.description} for p in ports]
                logger.info(f"Puertos detectados por serial.tools: {len(port_list)}")
            except Exception as e:
                logger.error(f"Error detectando puertos serie: {e}")
                port_list = []

            # En sistemas Unix/Linux, incluir solo puertos seriales reales relevantes
            if sys.platform.startswith('linux') or sys.platform.startswith('darwin'):
                logger.info("Detectando puertos seriales adicionales en sistema Unix/Mac...")
                try:
                    import glob
                    # Solo incluir puertos seriales reales, no todos los virtuales
                    # /dev/ttyUSB* (USB to serial adapters), /dev/ttyACM* (Arduino, modems), /dev/cu.* (macOS)
                    serial_ports = []
                    serial_ports.extend(glob.glob('/dev/ttyUSB*'))  # USB serial adapters
                    serial_ports.extend(glob.glob('/dev/ttyACM*'))  # Arduino, modems seriales
                    serial_ports.extend(glob.glob('/dev/cu.*'))     # macOS serial ports (cu = call-up)
                    serial_ports.extend(glob.glob('/dev/ttyS*'))    # Puertos serie estándar

                    logger.info(f"Puertos seriales reales encontrados: {len(serial_ports)}")
                    for vp in serial_ports:
                        if vp not in [p['device'] for p in port_list]:  # Evitar duplicados
                            # Intentar obtener una descripción más útil
                            description = f'Puerto serial: {vp.split("/")[-1]}'
                            port_list.append({'device': vp, 'description': description})
                            logger.info(f"Añadido puerto serial: {vp}")
                except Exception as e:
                    logger.error(f"Error detectando puertos seriales adicionales: {e}")

            # En Windows, buscar puertos adicionales
            if sys.platform.startswith('win'):
                logger.info("Detectando puertos adicionales en Windows...")
                try:
                    import winreg
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
                logger.info("Detectando impresoras en Windows...")
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
                if self.printer_manager.printer_name:
                    port_list.append({'device': self.printer_manager.printer_name, 'description': f'Impresora: {self.printer_manager.printer_name}'})
                    logger.info(f"Añadida impresora configurada: {self.printer_manager.printer_name}")

            logger.info(f"Total de puertos detectados: {len(port_list)}")

            if self.websocket:
                logger.info(f">>> Enviando ports_update al servidor con {len(port_list)} puertos...")
                data_to_send = {
                    'action': 'ports_update',
                    'ports': port_list,
                    'scale_port': self.scale_manager.port,
                    'scale_connected': self.scale_manager.connected,
                    'printer_port': self.printer_manager.printer_name,
                    'printer_connected': self.printer_manager.is_connected
                }
                logger.info(f"DEBUG DATA: {json.dumps(data_to_send)}")
                await self.send_data(data_to_send)
                logger.info(f"✓ Mensaje de puertos enviado exitosamente")

                # Registrar explícitamente qué datos se están enviando
                logger.info(f"Datos enviados - Scale port: {self.scale_manager.port}, Scale connected: {self.scale_manager.connected}")
                logger.info(f"Datos enviados - Printer port: {self.printer_manager.printer_name}, Printer connected: {self.printer_manager.is_connected}")
            else:
                logger.warning("No se pudo confirmar la suscripción para enviar la lista de puertos")
        except Exception as e:
            logger.error(f"Error al enviar la lista de puertos: {e}")
            logger.error(f"Error details: {str(e)}", exc_info=True)

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
    logger.info("Después de esperar 2 segundos")

    # Enviar la lista de puertos inmediatamente al iniciar
    try:
        await client.send_ports_list()
    except Exception as e:
        logger.error(f"Error al enviar la lista inicial de puertos: {e}")
        logger.error(f"Error details: {str(e)}", exc_info=True)

    logger.info("Entrando en el loop principal...")
    while True:
        try:
            logger.debug("Iniciando ciclo de actualización de puertos...")

            # Obtener puertos disponibles (misma lógica que arriba)
            try:
                ports = await asyncio.to_thread(serial.tools.list_ports.comports)
                port_list = [{'device': p.device, 'description': p.description} for p in ports]
            except Exception as e:
                logger.error(f"Error detectando puertos serie en loop: {e}")
                port_list = []

            # En sistemas Unix/Linux, incluir solo puertos seriales reales relevantes
            if sys.platform.startswith('linux') or sys.platform.startswith('darwin'):
                try:
                    import glob
                    # Solo incluir puertos seriales reales, no todos los virtuales
                    serial_ports = []
                    serial_ports.extend(glob.glob('/dev/ttyUSB*'))  # USB serial adapters
                    serial_ports.extend(glob.glob('/dev/ttyACM*'))  # Arduino, modems seriales
                    serial_ports.extend(glob.glob('/dev/cu.*'))     # macOS serial ports (cu = call-up)
                    serial_ports.extend(glob.glob('/dev/ttyS*'))    # Puertos serie estándar

                    for vp in serial_ports:
                        if vp not in [p['device'] for p in port_list]:  # Evitar duplicados
                            description = f'Puerto serial: {vp.split("/")[-1]}'
                            port_list.append({'device': vp, 'description': description})
                except Exception as e:
                    logger.error(f"Error detectando puertos seriales adicionales en loop: {e}")

            # En Windows, buscar puertos adicionales
            if sys.platform.startswith('win'):
                try:
                    import winreg
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
                    logger.warning(f"Error obteniendo impresoras Windows: {printer_error}")
            elif sys.platform == 'darwin' or sys.platform.startswith('linux'):
                # En Mac/Linux, intentar usar lpstat para listar impresoras
                try:
                    import subprocess
                    # Usar asyncio.to_thread para no bloquear el loop con subprocess
                    def get_unix_printers():
                        try:
                            output = subprocess.check_output(['lpstat', '-a'], stderr=subprocess.STDOUT, timeout=2).decode()
                            return [line.split()[0] for line in output.splitlines() if line.strip()]
                        except:
                            return []
                    
                    unix_printers = await asyncio.to_thread(get_unix_printers)
                    for printer in unix_printers:
                        if not any(p['device'] == printer for p in port_list):
                            port_list.append({'device': printer, 'description': f'Impresora (Unix): {printer}'})
                except Exception as e:
                    logger.debug(f"No se pudo ejecutar lpstat: {e}")

                # Siempre incluir la impresora configurada como opción si no se detectó
                if printer_manager.printer_name and not any(p['device'] == printer_manager.printer_name for p in port_list):
                    port_list.append({'device': printer_manager.printer_name, 'description': f'Impresora: {printer_manager.printer_name}'})

                # Refrescar estado de conexión de la impresora
                await asyncio.to_thread(printer_manager.connect_printer)

            # Solo enviar actualización si hay cambios significativos
            ports_changed = len(previous_ports) != len(port_list) or \
                           any(prev != curr for prev, curr in zip(previous_ports, port_list))

            if (ports_changed or
                scale_manager.connected != previous_scale_status or
                printer_manager.is_connected != previous_printer_status):

                if client.subscription_confirmed:
                    await client.send_data({
                        'action': 'ports_update',
                        'ports': port_list,
                        'scale_port': scale_manager.port,
                        'scale_connected': scale_manager.connected,
                        'printer_port': printer_manager.printer_name,
                        'printer_connected': printer_manager.is_connected
                    })
                previous_ports = port_list.copy()
                previous_scale_status = scale_manager.connected
                previous_printer_status = printer_manager.is_connected

            # Leer peso de la báscula en un hilo aparte para no bloquear el loop
            reading = await asyncio.to_thread(scale_manager.read_weight)
            
            if reading and isinstance(reading, dict) and reading.get('weight') is not None:
                from datetime import datetime # Import datetime here to ensure it's available
                await client.send_data({
                    'action': 'weight_update',
                    'weight': reading['weight'],
                    'timestamp': reading.get('timestamp', datetime.now().isoformat())
                })
            
            # Esperar antes de la próxima iteración
            await asyncio.sleep(3)
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
    initial_scale_port = args.scale_port or local_config.get('scale_port')
    initial_printer_port = args.printer_port or local_config.get('printer_port')

    scale_manager = ScaleManager(port=initial_scale_port)
    printer_manager = PrinterManager(printer_name=initial_printer_port)

    # Parámetros para manejo de reconexiones
    max_reconnection_delay = 60  # Máximo 60 segundos entre reconexiones
    reconnection_delay = 5      # Iniciar con 5 segundos
    backoff_factor = 1.5        # Factor de incremento exponencial

    try:
        import websockets
        logger.info(f"🔄 Iniciando bucle de conexión (websockets v{websockets.__version__})...")
    except:
        logger.info("🔄 Iniciando bucle de conexión...")

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
    parser.add_argument('--url', type=str, default=os.getenv('SERIAL_SERVER_URL', 'wss://wmsys.fly.dev/cable'), help='URL del servidor.')
    parser.add_argument('--token', type=str, default='f5284e6402cf64f9794711b91282e343', help='Token de autenticación.')
    parser.add_argument('--device-id', type=str, default='device-serial-6bca882ac82e4333afedfb48ac3eea8e', help='ID único del dispositivo.')
    parser.add_argument('--scale-port', type=str, default=None, help='Puerto de la báscula.')
    parser.add_argument('--printer-port', type=str, default=None, help='Nombre de la impresora.')
    args = parser.parse_args()

    # Si no se proporciona un device-id (y no hay default), usar uno basado en la máquina
    # En este caso tenemos un default hardcoded, pero mantenemos la lógica por si el usuario pasa cadena vacía
    device_id = args.device_id or f"device-serial-{uuid.getnode()}"

    print("-" * 50)
    print(f"🚀 INICIANDO CLIENTE SERIAL WMSYS")
    print(f"📍 Servidor: {args.url}")
    print(f"🔑 Device ID: {device_id}")
    print(f"⚖️ Báscula: {args.scale_port or 'Pendiente'}")
    print(f"🖨️ Impresora: {args.printer_port or 'Pendiente'}")
    print("-" * 50)

    try:
        asyncio.run(main_loop(args.url, args.token, device_id, args))
    except KeyboardInterrupt:
        logger.info("Cliente cerrado.")


