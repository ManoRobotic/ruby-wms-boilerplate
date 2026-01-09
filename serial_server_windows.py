#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Servidor Flask para comunicación serial con báscula e impresora
Versión modificada para Windows con soporte para win32print y WebSockets
"""
import sys
import os

# Configurar la codificación para evitar problemas con caracteres especiales en Windows
if sys.platform.startswith('win'):
    os.environ['PYTHONIOENCODING'] = 'utf-8'
    # Intentar configurar la consola para UTF-8 en Windows
    try:
        import subprocess
        subprocess.run(['chcp', '65001'], shell=True)  # Cambiar página de códigos a UTF-8
    except:
        pass

import argparse
from flask import Flask, request, jsonify, render_template
from flask_cors import CORS
from flask_socketio import SocketIO, emit, Namespace
import threading
import time
import json
import serial
import serial.tools.list_ports
from datetime import datetime
import csv
import os
import sys
import logging
import queue
import subprocess
from dataclasses import dataclass
from typing import Optional, Dict, Any
import webbrowser
import atexit
import gc
import weakref
from collections import deque, OrderedDict

# Importar win32print para impresión en Windows
try:
    import win32print
    import win32api
    WIN32_AVAILABLE = True
    print("✓ win32print disponible")
except ImportError:
    WIN32_AVAILABLE = False
    print("✗ win32print no disponible - instala con: pip install pywin32")

# Configurar logging mejorado con colores y formato
try:
    import colorlog
    # Crear formateador con colores
    handler = colorlog.StreamHandler()
    handler.setFormatter(colorlog.ColoredFormatter(
        "%(asctime)s - %(log_color)s%(levelname)-8s%(reset)s - %(name)s - %(message)s",
        datefmt='%Y-%m-%d %H:%M:%S',
        log_colors={
            'DEBUG':    'cyan',
            'INFO':     'green',
            'WARNING':  'yellow',
            'ERROR':    'red',
            'CRITICAL': 'red,bg_white',
        }
    ))

    # Configurar logger
    logger = colorlog.getLogger(__name__)
    logger.setLevel(logging.INFO)
    logger.addHandler(handler)
except ImportError:
    # Si no está disponible colorlog, usar logging estándar
    import logging
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
    logger = logging.getLogger(__name__)

# También mantener el logging estándar para archivos si es necesario
file_handler = logging.FileHandler('server.log')
file_formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(name)s - %(message)s')
file_handler.setFormatter(file_formatter)
logger.addHandler(file_handler)

# Configurar Flask con el directorio de plantillas
template_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'templates')
app = Flask(__name__, template_folder=template_dir)

# Configurar CORS para dominios específicos
cors_origins = [
    'http://localhost:3000',
    'https://wmsys.fly.dev',
    '*.ngrok-free.app',
    'http://localhost:*',
    'http://127.0.0.1:*',
    'https://75b43b34e0a2.ngrok-free.app'  # Dominio específico de ngrok actual
]
CORS(app, origins=cors_origins, supports_credentials=True, resources={
    r"/*": {"origins": cors_origins}
})

# Configurar SocketIO con soporte para diferentes transportes y límites de conexión
MAX_WS_CONNECTIONS = 50  # Límite de conexiones WebSocket simultáneas
current_ws_connections = 0
ws_connections_lock = threading.Lock()

socketio = SocketIO(
    app,
    cors_allowed_origins='*',  # Permitir todos los orígenes temporalmente para resolver problema
    allow_unsafe_werkzeug=True,
    transports=['websocket', 'polling'],  # Especificar transportes permitidos
    max_http_buffer_size=100000,  # Limitar buffer HTTP
    ping_timeout=60,  # Timeout de ping aumentado
    ping_interval=25,  # Intervalo de ping
    engineio_logger=True,  # Habilitar logging de engine.io para debugging
    logger=True  # Habilitar logging de SocketIO
)

# Variables globales con optimización de memoria
MAX_QUEUE_SIZE = 100  # Limitar el tamaño de la cola para evitar acumulación
scale_data_queue = queue.Queue(maxsize=MAX_QUEUE_SIZE)
server_connected = False
connection_lock = threading.RLock()  # RLock para evitar deadlocks
scale_thread = None
scale_running = False

# Buffer para lecturas de báscula (evitar saturación)
WEIGHT_READINGS_BUFFER = deque(maxlen=50)  # Limitar a 50 lecturas recientes
WEIGHT_READINGS_LOCK = threading.Lock()

# Métricas de rendimiento
PERFORMANCE_METRICS = {
    'readings_count': 0,
    'errors_count': 0,
    'connections_count': 0,
    'start_time': time.time(),
    'avg_read_time': 0,
    'active_connections': 0
}
METRICS_LOCK = threading.Lock()

@dataclass
class ScaleReading:
    weight: str
    timestamp: str
    status: str = "success"

@dataclass
class PrintJob:
    content: str
    timestamp: str
    status: str = "pending"

class ScaleManager:
    def __init__(self, port='COM3', baudrate=115200, parity='N', stopbits=1, bytesize=8):
        self.port = port
        self.baudrate = baudrate
        self.parity = parity
        self.stopbits = stopbits
        self.bytesize = bytesize
        self.serial_connection = None
        self.is_running = False
        self.last_reading = None
        self.connected = False
        self.read_thread = None
        self.stop_event = threading.Event()  # Evento para detener la lectura
        self.reconnect_attempts = 0
        self.max_reconnect_attempts = 5
        self.reconnect_delay = 5  # segundos

    def connect(self) -> bool:
        """Conecta a la báscula"""
        try:
            # Verificar si ya está conectado
            if self.serial_connection and self.serial_connection.is_open:
                logger.info(f"Báscula ya conectada en {self.port}")
                return True

            # Cerrar conexión anterior si existe
            if self.serial_connection:
                try:
                    self.serial_connection.close()
                except:
                    pass  # Ignorar errores al cerrar conexión anterior
                self.serial_connection = None

            # Mostrar puertos disponibles
            available_ports = serial.tools.list_ports.comports()
            logger.info("Puertos seriales disponibles:")
            for port in available_ports:
                logger.info(f"  - {port.device}")

            # Verificar si el puerto está en la lista de puertos disponibles
            port_available = any(port.device == self.port for port in available_ports)
            if not port_available:
                logger.error(f"✗ El puerto {self.port} no está disponible")
                return False

            # Intentar abrir la conexión serial con manejo de errores específico
            try:
                self.serial_connection = serial.Serial(
                    self.port,
                    baudrate=self.baudrate,
                    timeout=1,
                    parity=self.parity,
                    stopbits=self.stopbits,
                    bytesize=self.bytesize
                )
            except serial.SerialException as se:
                logger.error(f"Error SerialException: {str(se)}")

                # Intentar reiniciar el puerto físico primero
                try:
                    # Simular un "reinicio" del puerto cerrándolo y esperando
                    if self.serial_connection:
                        self.serial_connection.close()
                    time.sleep(1)  # Esperar 1 segundo antes de reintentar
                except:
                    pass

                # Intentar con configuración más genérica
                try:
                    self.serial_connection = serial.Serial(
                        self.port,
                        baudrate=self.baudrate,
                        timeout=1
                    )
                except Exception as fallback_error:
                    logger.error(f"Fallback connection also failed: {str(fallback_error)}")

                    # Ultimo intento: usar solo el puerto con valores por defecto
                    try:
                        self.serial_connection = serial.Serial(
                            self.port,
                            timeout=1  # Solo timeout, dejar otros valores por defecto
                        )
                    except:
                        # Si todo falla, intentar un enfoque alternativo para resolver el problema de Windows
                        self._handle_windows_port_issue(self.port)
                        # Re-lanzar el error original
                        raise se

            # Verificar que la conexión es funcional
            if self.serial_connection and self.serial_connection.is_open:
                # Limpiar buffers
                self.serial_connection.reset_input_buffer()
                self.serial_connection.reset_output_buffer()

            self.connected = True
            self.reconnect_attempts = 0  # Reiniciar contador de reconexión

            # Actualizar métricas
            with METRICS_LOCK:
                PERFORMANCE_METRICS['connections_count'] += 1

            print(f"✅ Conexión establecida en el puerto {self.port}")
            logger.info(f"Conexión establecida en el puerto {self.port}")
            return True

        except serial.SerialException as e:
            print(f"❌ Error de conexión serial: {str(e)}")
            logger.error(f"Error de conexión serial: {str(e)}")
            return False
        except PermissionError as e:
            print(f"❌ Error de permiso al acceder al puerto serial: {str(e)}")
            logger.error(f"Error de permiso al acceder al puerto serial: {str(e)}")
            logger.error("Este error puede ocurrir si:")
            logger.error("  - Otro programa está usando el puerto")
            logger.error("  - No tienes permisos suficientes")
            logger.error("  - El dispositivo no está funcionando correctamente")
            logger.error("  - El puerto está en un estado inconsistente")

            # Intentar liberar forzosamente el puerto
            self.force_release_port(self.port)

            # Manejar el problema específico de Windows
            self._handle_windows_port_issue(self.port)

            # Incrementar contador de reconexión
            self.reconnect_attempts += 1
            logger.warning(f"Intento de reconexión #{self.reconnect_attempts}")

            # Actualizar métricas
            with METRICS_LOCK:
                PERFORMANCE_METRICS['errors_count'] += 1

            # Intentar reiniciar el puerto
            try:
                # Cerrar cualquier conexión existente
                if self.serial_connection:
                    self.serial_connection.close()
                    self.serial_connection = None
                # Pequeña pausa antes de reintentar
                time.sleep(1)  # Aumentar el tiempo de espera
            except:
                pass
            return False
        except OSError as e:
            logger.error(f"✗ Error del sistema al acceder al puerto serial: {str(e)}")
            logger.error("Este error puede indicar que el puerto no está disponible o tiene problemas físicos")

            # Manejar el problema específico de Windows
            self._handle_windows_port_issue(self.port)

            # Incrementar contador de reconexión
            self.reconnect_attempts += 1
            logger.warning(f"Intento de reconexión #{self.reconnect_attempts}")

            # Actualizar métricas
            with METRICS_LOCK:
                PERFORMANCE_METRICS['errors_count'] += 1

            # Intentar solución de problemas de puerto
            try:
                # Cerrar cualquier conexión existente
                if self.serial_connection:
                    self.serial_connection.close()
                    self.serial_connection = None
                # Esperar antes de reintentar
                time.sleep(1)
            except:
                pass
            return False
        except Exception as e:
            logger.error(f"✗ Error inesperado al conectar con la báscula: {str(e)}")
            # Registrar el traceback completo para debugging
            import traceback
            logger.error(f"Detalle del error: {traceback.format_exc()}")
            return False

    def _handle_windows_port_issue(self, port):
        """Maneja problemas específicos de Windows con puertos seriales"""
        logger.info(f"Intentando resolver problema de puerto en Windows para {port}")

        # En Windows, a veces necesitamos reiniciar el dispositivo
        # Este es un mensaje informativo ya que no podemos manipular directamente el hardware desde Python
        logger.info("Para resolver este problema en Windows:")
        logger.info("1. Verifique que ningún otro programa esté usando el puerto")
        logger.info("2. Intente desconectar y volver a conectar el dispositivo físico")
        logger.info("3. Reinicie el servicio de dispositivo serial si es posible")
        logger.info("4. Ejecute el programa como administrador")

        # Intentar verificar si el puerto está realmente disponible
        try:
            import subprocess
            # Comando para verificar el estado del puerto (solo para información)
            result = subprocess.run(['mode', port], capture_output=True, text=True, shell=True)
            if result.returncode != 0:
                logger.info(f"Puerto {port} parece tener problemas adicionales: {result.stderr}")
        except Exception as e:
            logger.info(f"No se pudo verificar el estado del puerto: {str(e)}")

    def force_release_port(self, port):
        """Intenta liberar forzosamente un puerto serial en Windows"""
        try:
            import subprocess
            import psutil

            # Buscar procesos que puedan estar usando el puerto
            for proc in psutil.process_iter(['pid', 'name', 'connections']):
                try:
                    connections = proc.info['connections']
                    if connections:
                        for conn in connections:
                            if hasattr(conn, 'laddr') and hasattr(conn, 'raddr'):
                                # No aplicable a puertos seriales, pero útil para TCP
                                pass
                except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                    continue

            # En sistemas Windows, a veces hay que reiniciar servicios o matar procesos
            # que tienen el puerto abierto, pero esto requiere herramientas específicas
            logger.info(f"Intentando liberar puerto {port}...")

        except ImportError:
            logger.info("psutil no está instalado, no se puede verificar procesos que usan el puerto")
        except Exception as e:
            logger.error(f"Error intentando liberar puerto: {str(e)}")

    def disconnect(self):
        """Desconecta la báscula"""
        if self.serial_connection:
            try:
                if self.serial_connection.is_open:
                    self.serial_connection.close()
                self.connected = False
                print("✓ Puerto serial cerrado correctamente")
                logger.info("Puerto serial cerrado correctamente")
            except Exception as e:
                logger.error(f"Error al cerrar puerto serial: {str(e)}")
            finally:
                self.serial_connection = None

    def read_weight(self, timeout=5) -> Optional[ScaleReading]:
        """Lee un peso de la báscula, con un timeout"""
        if not self.serial_connection or not self.serial_connection.is_open:
            logger.error("La conexión serial no está abierta.")
            return None

        start_time = time.time()
        read_start = time.time()

        try:
            logger.info("Esperando datos de la báscula...")
            while time.time() - start_time < timeout:
                if self.serial_connection.in_waiting > 0:
                    data = self.serial_connection.readline().decode('utf-8', errors='ignore').strip()
                    logger.info(f"Datos recibidos: '{data}'")

                    if data:
                        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

                        reading = ScaleReading(weight=data, timestamp=timestamp)
                        self.last_reading = reading

                        # Agregar a buffer de lecturas
                        with WEIGHT_READINGS_LOCK:
                            WEIGHT_READINGS_BUFFER.append(reading)

                        # Escribir a CSV
                        self._save_to_csv(reading)

                        # Emitir evento de WebSocket
                        try:
                            socketio.emit('weight_update', {
                                'weight': float(data),
                                'timestamp': datetime.now().isoformat()
                            }, namespace='/weight')
                        except ValueError:
                            # Si no se puede convertir a float, emitir como string
                            socketio.emit('weight_update', {
                                'weight': data,
                                'timestamp': datetime.now().isoformat()
                            }, namespace='/weight')

                        # Actualizar métricas
                        with METRICS_LOCK:
                            PERFORMANCE_METRICS['readings_count'] += 1
                            read_duration = time.time() - read_start
                            PERFORMANCE_METRICS['avg_read_time'] = (
                                PERFORMANCE_METRICS['avg_read_time'] * (PERFORMANCE_METRICS['readings_count'] - 1) + read_duration
                            ) / PERFORMANCE_METRICS['readings_count']

                        # Print to console immediately when data is received
                        print(f"\033[92m[{timestamp}]\033[0m Peso: \033[93m{data}\033[0m")

                        return reading
                time.sleep(0.1)

            logger.warning("No se recibieron datos en el tiempo esperado.")

        except serial.SerialException as e:
            logger.error(f"Error de comunicación serial leyendo báscula: {str(e)}")

            # Actualizar métricas
            with METRICS_LOCK:
                PERFORMANCE_METRICS['errors_count'] += 1
        except Exception as e:
            logger.error(f"Error inesperado leyendo báscula: {str(e)}")

            # Actualizar métricas
            with METRICS_LOCK:
                PERFORMANCE_METRICS['errors_count'] += 1

        return None

    def _save_to_csv(self, reading: ScaleReading):
        """Guarda lectura en archivo CSV"""
        try:
            csv_file = './peso.csv'
            with open(csv_file, 'w', newline='') as file:
                writer = csv.writer(file)
                writer.writerow([reading.timestamp, reading.weight])
        except Exception as e:
            logger.error(f"Error guardando CSV: {str(e)}")

    def start_continuous_reading(self):
        """Inicia lectura continua en hilo separado con mecanismos de recuperación"""
        if self.is_running:
            logger.info("Lectura continua ya está en ejecución")
            return

        self.is_running = True
        self.stop_event.clear()

        def read_loop():
            consecutive_errors = 0
            max_consecutive_errors = 10  # Número máximo de errores consecutivos antes de intentar reconexión
            error_backoff_time = 1  # Tiempo base para retroceso exponencial
            last_successful_read = time.time()

            while self.is_running and not self.stop_event.is_set():
                try:
                    reading = self.read_weight(timeout=2)  # Reducir timeout para lectura continua
                    if reading:
                        # Solo agregar a la cola si hay espacio
                        try:
                            scale_data_queue.put_nowait(reading)
                        except queue.Full:
                            # Si la cola está llena, remover el elemento más antiguo
                            try:
                                scale_data_queue.get_nowait()  # Remover el más antiguo
                                scale_data_queue.put_nowait(reading)  # Agregar el nuevo
                            except:
                                pass  # Ignorar si ambos fallan

                        # Print to console with colored output
                        print(f"\033[92m[{reading.timestamp}]\033[0m Peso: \033[93m{reading.weight}\033[0m")

                        # Reiniciar contador de errores y tiempo de retroceso
                        consecutive_errors = 0
                        error_backoff_time = 1
                        last_successful_read = time.time()
                    else:
                        # Incrementar contador de errores si no se obtuvo lectura
                        consecutive_errors += 1

                        # Si hay demasiados errores consecutivos, intentar reconectar
                        if consecutive_errors >= max_consecutive_errors:
                            logger.warning(f"Demasiados errores consecutivos ({consecutive_errors}), intentando reconexión...")

                            # Desconectar y reconectar
                            self.disconnect()
                            time.sleep(3)  # Esperar antes de reconectar

                            if not self.connect():
                                logger.error("No se pudo reconectar después de errores consecutivos")
                                # Esperar más tiempo antes de intentar nuevamente
                                time.sleep(15)

                            consecutive_errors = 0  # Reiniciar contador
                            error_backoff_time = 1  # Reiniciar retroceso
                        else:
                            # Aumentar el tiempo de espera exponencialmente para reducir intentos fallidos
                            backoff_time = min(error_backoff_time * (1.5 ** min(consecutive_errors, 5)), 5)  # Máximo 5 segundos
                            time.sleep(backoff_time)

                    # Si no hay errores recientes, esperar un poco antes del próximo intento
                    if consecutive_errors == 0:
                        time.sleep(0.5)  # Esperar medio segundo entre lecturas exitosas
                    elif consecutive_errors < max_consecutive_errors:
                        # En modo de error, esperar menos tiempo para intentar recuperar más rápido
                        time.sleep(0.2)

                except Exception as e:
                    logger.error(f"Error en lectura continua: {str(e)}")
                    consecutive_errors += 1

                    # Actualizar métricas
                    with METRICS_LOCK:
                        PERFORMANCE_METRICS['errors_count'] += 1

                    if consecutive_errors >= max_consecutive_errors:
                        logger.warning(f"Demasiados errores consecutivos ({consecutive_errors}), intentando reconexión...")

                        # Desconectar y reconectar
                        self.disconnect()
                        time.sleep(3)  # Esperar antes de reconectar

                        if not self.connect():
                            logger.error("No se pudo reconectar después de errores consecutivos")
                            # Esperar más tiempo antes de intentar nuevamente
                            time.sleep(15)

                        consecutive_errors = 0  # Reiniciar contador
                        error_backoff_time = 1  # Reiniciar retroceso
                    else:
                        # Esperar antes de continuar con retroceso exponencial
                        backoff_time = min(error_backoff_time * (1.5 ** min(consecutive_errors, 5)), 5)
                        time.sleep(backoff_time)

        # Usar un daemon thread para que no impida el cierre del programa
        self.read_thread = threading.Thread(target=read_loop, daemon=True)
        self.read_thread.start()
        print("✓ Lectura continua iniciada")
        logger.info("Lectura continua iniciada")

    def stop_continuous_reading(self):
        """Detiene lectura continua"""
        self.is_running = False
        if self.stop_event:
            self.stop_event.set()
        if self.read_thread and self.read_thread.is_alive():
            self.read_thread.join(timeout=2)  # Esperar hasta 2 segundos
        print("✓ Lectura continua detenida")
        logger.info("Lectura continua detenida")

class PrinterManager:
    def __init__(self):
        self.printer_name = None
        self.printer_handle = None
        self.is_connected = False

    def connect_printer(self) -> bool:
        """Verifica que la impresora TSC TX200 esté disponible usando win32print"""
        if not WIN32_AVAILABLE:
            logger.error("✗ win32print no está disponible")
            return False

        try:
            # Verificar si ya está conectado
            if self.is_connected and self.printer_name:
                logger.info(f"Impresora ya conectada: {self.printer_name}")
                return True

            # Buscar la impresora TSC TX200 en las impresoras instaladas
            printers = [printer[2] for printer in win32print.EnumPrinters(win32print.PRINTER_ENUM_LOCAL | win32print.PRINTER_ENUM_CONNECTIONS)]

            tsc_printers = [p for p in printers if 'TSC' in p.upper() and 'TX200' in p.upper()]

            if not tsc_printers:
                logger.error("✗ No se encontró la impresora TSC TX200 en las impresoras instaladas")
                logger.info("Impresoras disponibles:")
                for p in printers:
                    logger.info(f"  - {p}")
                return False

            self.printer_name = tsc_printers[0]  # Tomar la primera coincidencia
            self.is_connected = True
            print(f"✓ Impresora disponible: {self.printer_name}")
            logger.info(f"Impresora disponible: {self.printer_name}")
            return True

        except Exception as e:
            logger.error(f"✗ Error verificando la impresora: {str(e)}")
            return False

    def disconnect(self):
        """Desconecta de la impresora"""
        if self.printer_handle:
            try:
                win32print.ClosePrinter(self.printer_handle)
                self.printer_handle = None
                self.is_connected = False
                print("✓ Desconectado de la impresora")
                logger.info("Desconectado de la impresora")
            except Exception as e:
                logger.error(f"Error desconectando: {str(e)}")

    def print_label(self, content: str, ancho_mm: int = 80, alto_mm: int = 50) -> bool:
        """Imprime etiqueta usando win32print con formato RAW correcto"""
        if not WIN32_AVAILABLE:
            logger.error("✗ win32print no está disponible")
            return False

        try:
            # Obtener el nombre de la impresora
            printers = [printer[2] for printer in win32print.EnumPrinters(win32print.PRINTER_ENUM_LOCAL | win32print.PRINTER_ENUM_CONNECTIONS)]
            tsc_printers = [p for p in printers if 'TSC' in p.upper() and 'TX200' in p.upper()]

            if not tsc_printers:
                logger.error("✗ No se encontró la impresora TSC TX200")
                return False

            printer_name = tsc_printers[0]
            logger.info(f"=== IMPRIMIENDO ETIQUETA CON WIN32PRINT ===")
            logger.info(f"Tamaño: {ancho_mm}x{alto_mm}mm")
            logger.info(f"Enviando a impresora: {printer_name}")

            # Abrir la impresora
            printer_handle = win32print.OpenPrinter(printer_name)

            # Preparar el trabajo de impresión con información más específica
            job = win32print.StartDocPrinter(printer_handle, 1, ("TSC Label Job", None, "RAW"))
            win32print.StartPagePrinter(printer_handle)

            # Convertir el contenido TSPL a bytes y enviar
            if isinstance(content, str):
                content_bytes = content.encode('utf-8')
            else:
                content_bytes = content

            # Enviar datos a la impresora
            bytes_written = win32print.WritePrinter(printer_handle, content_bytes)
            logger.info(f"Bytes escritos: {bytes_written}")

            # Finalizar el trabajo de impresión
            win32print.EndPagePrinter(printer_handle)
            win32print.EndDocPrinter(printer_handle)
            win32print.ClosePrinter(printer_handle)

            print("✓ Etiqueta impresa exitosamente")
            logger.info("Etiqueta impresa exitosamente")
            return True

        except Exception as e:
            logger.error(f"✗ Error imprimiendo: {str(e)}")
            import traceback
            logger.error(f"Detalle del error: {traceback.format_exc()}")
            return False

    def print_label_with_config(self, content: str, ancho_mm: int = 80, alto_mm: int = 50) -> bool:
        """Imprime etiqueta sin modificar configuración de la impresora"""
        if not WIN32_AVAILABLE:
            logger.error("✗ win32print no está disponible")
            return False

        # Asegurar que el contenido tenga el tamaño de etiqueta y esté bien formateado
        # Usar el mismo formato que sabemos que funciona con el test
        if not content.startswith("SIZE"):
            # Asegurar que siempre haya un PRINT al final
            if "PRINT" not in content.upper():
                content += "\nPRINT 1,1"
            full_content = f"SIZE {ancho_mm} mm, {alto_mm} mm\n{content}"
        else:
            full_content = content
        return self.print_label(full_content, ancho_mm, alto_mm)

    def test_impresora(self, ancho_mm: int = 80, alto_mm: int = 50) -> bool:
        """Test básico de impresión con comandos gráficos que funcionan en tu impresora"""
        if not WIN32_AVAILABLE:
            logger.error("✗ win32print no está disponible")
            return False

        try:
            logger.info("=== TEST DE IMPRESORA CON WIN32PRINT ===")
            logger.info(f"Configurando para papel: {ancho_mm}mm x {alto_mm}mm")

            # Contenido de prueba con comandos gráficos que funcionan en tu impresora
            test_content = f"""SIZE {ancho_mm} mm, {alto_mm} mm
CLS
BARCODE 100,100,"128",50,1,0,2,2,"{ancho_mm}x{alto_mm}mm"
QRCODE 200,100,L,5,A,M2,S7,"TSC-TX200-TEST"
TEXT 100,200,"TSC TEST"
PRINT 1,1
"""

            return self.print_label(test_content, ancho_mm, alto_mm)

        except Exception as e:
            logger.error(f"✗ Error en test de impresora: {str(e)}")
            return False

# Instancias globales
scale_manager = ScaleManager()
printer_manager = PrinterManager()

# WebSocket Namespace para peso
class WeightNamespace(Namespace):
    def on_connect(self):
        global current_ws_connections
        with ws_connections_lock:
            if current_ws_connections >= MAX_WS_CONNECTIONS:
                print(f"⚠️  Límite de conexiones WebSocket alcanzado: {MAX_WS_CONNECTIONS}")
                logger.warning(f"Límite de conexiones WebSocket alcanzado: {MAX_WS_CONNECTIONS}")
                # Rechazar la conexión
                return False

        print(f"🔗 Cliente WebSocket conectado al namespace /weight (total: {current_ws_connections + 1})")
        logger.info(f"Cliente WebSocket conectado al namespace /weight (total: {current_ws_connections + 1})")
        with ws_connections_lock:
            current_ws_connections += 1
        with METRICS_LOCK:
            PERFORMANCE_METRICS['active_connections'] += 1
        emit('connected', {'data': 'Conectado al stream de peso'}, namespace='/weight')

    def on_disconnect(self):
        global current_ws_connections
        with ws_connections_lock:
            current_ws_connections = max(0, current_ws_connections - 1)
        print(f".unlink Cliente WebSocket desconectado del namespace /weight (activas: {current_ws_connections})")
        logger.info(f"Cliente WebSocket desconectado del namespace /weight (activas: {current_ws_connections})")
        with METRICS_LOCK:
            PERFORMANCE_METRICS['active_connections'] -= 1

socketio.on_namespace(WeightNamespace('/weight'))

# Endpoints REST
@app.route('/')
def index():
    """Página principal del monitor serial"""
    return render_template('index.html')

@app.route('/health', methods=['GET'])
def health_check():
    """Endpoint de salud del servidor detallado"""
    with METRICS_LOCK:
        uptime = time.time() - PERFORMANCE_METRICS['start_time']
        active_connections = PERFORMANCE_METRICS['active_connections']

    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'scale_connected': scale_manager.connected,
        'printer_connected': printer_manager.is_connected,
        'scale_port': scale_manager.port if scale_manager.connected else None,
        'printer_port': printer_manager.printer_name if printer_manager.is_connected else None,
        'services': {
            'scale': scale_manager.is_running,
            'printer': printer_manager.is_connected
        },
        'performance': {
            'uptime_seconds': round(uptime, 2),
            'readings_count': PERFORMANCE_METRICS['readings_count'],
            'errors_count': PERFORMANCE_METRICS['errors_count'],
            'avg_read_time': round(PERFORMANCE_METRICS['avg_read_time'], 4),
            'active_connections': active_connections
        }
    })

@app.route('/scale/connect', methods=['POST'])
def connect_scale():
    """Conecta a la báscula con soporte idempotente"""
    data = request.get_json() or {}
    port = data.get('port', 'COM3')
    baudrate = data.get('baudrate', 115200)

    # Actualizar configuración
    scale_manager.port = port
    scale_manager.baudrate = baudrate

    # Verificar si ya está conectado con el mismo puerto
    if scale_manager.serial_connection and scale_manager.serial_connection.is_open and scale_manager.port == port:
        logger.info(f"Báscula ya conectada en {port}")
        return jsonify({'status': 'success', 'message': f'Báscula ya conectada en {port}', 'already_connected': True})

    if scale_manager.connect():
        return jsonify({'status': 'success', 'message': 'Báscula conectada'})
    else:
        return jsonify({'status': 'error', 'message': 'Error conectando báscula'}), 500

@app.route('/scale/disconnect', methods=['POST'])
def disconnect_scale():
    """Desconecta la báscula"""
    scale_manager.stop_continuous_reading()
    scale_manager.disconnect()
    response = jsonify({'status': 'success', 'message': 'Báscula desconectada'})
    response.headers.add('Access-Control-Allow-Origin', '*') # Add this line
    return response

@app.route('/scale/start', methods=['POST'])
def start_scale_reading():
    """Inicia lectura continua de la báscula"""
    if not scale_manager.serial_connection:
        return jsonify({'status': 'error', 'message': 'Báscula no conectada'}), 400

    scale_manager.start_continuous_reading()
    return jsonify({'status': 'success', 'message': 'Lectura continua iniciada'})

@app.route('/scale/stop', methods=['POST'])
def stop_scale_reading():
    """Detiene lectura continua de la báscula"""
    scale_manager.stop_continuous_reading()
    return jsonify({'status': 'success', 'message': 'Lectura continua detenida'})

@app.route('/scale/read', methods=['GET'])
def read_scale():
    """Lee peso actual de la báscula"""
    reading = scale_manager.read_weight(timeout=10) # Wait up to 10 seconds
    if reading:
        return jsonify({
            'status': 'success',
            'weight': reading.weight,
            'timestamp': reading.timestamp
        })
    else:
        return jsonify({'status': 'error', 'message': 'No se pudo leer la báscula'}), 500

@app.route('/scale/last', methods=['GET'])
def get_last_reading():
    """Obtiene última lectura de la báscula"""
    if scale_manager.last_reading:
        return jsonify({
            'status': 'success',
            'weight': scale_manager.last_reading.weight,
            'timestamp': scale_manager.last_reading.timestamp
        })
    else:
        return jsonify({'status': 'error', 'message': 'No hay lecturas disponibles'}), 404

@app.route('/scale/latest', methods=['GET'])
def get_latest_from_queue():
    """Obtiene lecturas más recientes del buffer"""
    readings = []

    # Obtener lecturas del buffer
    with WEIGHT_READINGS_LOCK:
        for reading in list(WEIGHT_READINGS_BUFFER):  # Copia para evitar problemas de concurrencia
            readings.append({
                'weight': reading.weight,
                'timestamp': reading.timestamp,
                'status': reading.status
            })
            # También imprimir en consola para debugging
            print(f"\033[94m[API REQUEST]\033[0m [{reading.timestamp}] Peso: \033[93m{reading.weight}\033[0m")

    # Vaciar la cola para evitar duplicados
    try:
        while not scale_data_queue.empty():
            scale_data_queue.get_nowait()
    except queue.Empty:
        pass

    return jsonify({'status': 'success', 'readings': readings})

@app.route('/printer/connect', methods=['POST'])
def connect_printer():
    """Conecta a la impresora con soporte idempotente"""
    if not WIN32_AVAILABLE:
        return jsonify({'status': 'error', 'message': 'win32print no disponible'}), 500

    # Verificar si ya está conectado
    if printer_manager.is_connected and printer_manager.printer_name:
        logger.info(f"Impresora ya conectada: {printer_manager.printer_name}")
        return jsonify({
            'status': 'success',
            'message': f'Impresora ya conectada: {printer_manager.printer_name}',
            'printer_name': printer_manager.printer_name,
            'already_connected': True
        })

    if printer_manager.connect_printer():
        return jsonify({'status': 'success', 'message': f'Impresora conectada: {printer_manager.printer_name}', 'printer_name': printer_manager.printer_name})
    else:
        return jsonify({'status': 'error', 'message': 'Error conectando impresora'}), 500

@app.route('/connect', methods=['POST'])
def connect_port():
    """Conecta a un puerto serial"""
    data = request.get_json()
    if not data or 'port' not in data:
        return jsonify({'status': 'error', 'message': 'Puerto requerido'}), 400

    port = data['port']

    # Para puertos seriales tradicionales
    try:
        # Verificar si ya está conectado
        if scale_manager.serial_connection and scale_manager.serial_connection.is_open and scale_manager.port == port:
            return jsonify({'status': 'success', 'message': f'Puerto {port} ya conectado', 'already_connected': True})

        # Configurar el puerto en el manager de báscula
        scale_manager.port = port
        if scale_manager.connect():
            return jsonify({'status': 'success', 'message': 'Conexión serial establecida'})
        else:
            return jsonify({'status': 'error', 'message': f'Error conectando al puerto {port}'}), 500
    except Exception as e:
        logger.error(f"Error conectando al puerto {port}: {str(e)}")
        return jsonify({'status': 'error', 'message': f'Error conectando al puerto: {str(e)}'}), 500

@app.route('/printer/print', methods=['POST'])
def print_label():
    """Imprime etiqueta"""
    if not WIN32_AVAILABLE:
        return jsonify({'status': 'error', 'message': 'win32print no disponible'}), 500

    data = request.get_json()
    if not data or 'content' not in data:
        return jsonify({'status': 'error', 'message': 'Contenido requerido'}), 400

    content = data['content']
    ancho_mm = data.get('ancho_mm', 80)
    alto_mm = data.get('alto_mm', 50)

    if printer_manager.print_label_with_config(content, ancho_mm, alto_mm):
        return jsonify({'status': 'success', 'message': 'Etiqueta impresa'})
    else:
        return jsonify({'status': 'error', 'message': 'Error imprimiendo'}), 500

@app.route('/printer/test', methods=['POST'])
def test_printer():
    """Ejecuta test de impresora"""
    if not WIN32_AVAILABLE:
        return jsonify({'status': 'error', 'message': 'win32print no disponible'}), 500

    data = request.get_json() or {}
    ancho_mm = data.get('ancho_mm', 80)
    alto_mm = data.get('alto_mm', 50)

    if printer_manager.test_impresora(ancho_mm, alto_mm):
        return jsonify({'status': 'success', 'message': 'Test de impresora ejecutado'})
    else:
        return jsonify({'status': 'error', 'message': 'Error en test de impresora'}), 500

@app.route('/printer/disconnect', methods=['POST'])
def disconnect_printer():
    """Desconecta la impresora"""
    printer_manager.disconnect()
    return jsonify({'status': 'success', 'message': 'Impresora desconectada'})

@app.route('/ports', methods=['GET'])
def list_serial_ports():
    """Lista puertos seriales e impresoras disponibles"""
    ports = []
    try:
        for port in serial.tools.list_ports.comports():
            ports.append({
                'device': port.device,
                'description': port.description,
                'hwid': port.hwid,
                'vid': port.vid,
                'pid': port.pid,
                'type': 'serial'
            })
            logger.info(f"Puerto encontrado: {port.device} - {port.description} (VID: {port.vid}, PID: {port.pid})")
    except Exception as e:
        logger.error(f"Error listando puertos seriales: {str(e)}")

    # Agregar impresoras Windows si win32print está disponible
    if WIN32_AVAILABLE:
        try:
            printers = [printer[2] for printer in win32print.EnumPrinters(win32print.PRINTER_ENUM_LOCAL | win32print.PRINTER_ENUM_CONNECTIONS)]
            for printer_name in printers:
                printer_type = 'printer'
                if 'TSC' in printer_name.upper() and 'TX200' in printer_name.upper():
                    printer_type = 'printer_tsc_tx200'

                ports.append({
                    'device': printer_name,
                    'description': f'Windows Printer - {printer_name}',
                    'hwid': 'WINDOWS_PRINTER',
                    'vid': None,
                    'pid': None,
                    'type': printer_type
                })
                logger.info(f"Impresora encontrada: {printer_name}")
        except Exception as e:
            logger.error(f"Error listando impresoras: {str(e)}")
    else:
        logger.warning("win32print no disponible - no se pueden listar impresoras")

    logger.info(f"Total de dispositivos encontrados: {len(ports)}")
    return jsonify({'status': 'success', 'ports': ports, 'total': len(ports)})

@app.route('/metrics', methods=['GET'])
def get_metrics():
    """Obtiene métricas de rendimiento del sistema"""
    with METRICS_LOCK:
        uptime = time.time() - PERFORMANCE_METRICS['start_time']
        metrics_copy = PERFORMANCE_METRICS.copy()
        metrics_copy['uptime'] = uptime

        # Agregar métricas de sistema
        try:
            import psutil
            metrics_copy['system'] = {
                'cpu_percent': psutil.cpu_percent(interval=1),
                'memory_percent': psutil.virtual_memory().percent,
                'disk_usage': psutil.disk_usage('/').percent if os.name != 'nt' else psutil.disk_usage('C:\\').percent
            }
        except ImportError:
            metrics_copy['system'] = {
                'cpu_percent': 'unknown',
                'memory_percent': 'unknown',
                'disk_usage': 'unknown'
            }
        except Exception:
            metrics_copy['system'] = {
                'cpu_percent': 'error',
                'memory_percent': 'error',
                'disk_usage': 'error'
            }

    return jsonify({'status': 'success', 'metrics': metrics_copy})

def diagnosticar_puertos():
    """Diagnóstico de puertos seriales"""
    print("=" * 60)
    print("DIAGNÓSTICO DE PUERTOS SERIALES")
    print("=" * 60)

    # 1. Listar todos los puertos seriales
    print("\n1. PUERTOS SERIALES DISPONIBLES:")
    print("-" * 40)

    try:
        ports = list(serial.tools.list_ports.comports())
        if not ports:
            print("   ✗ No se encontraron puertos seriales en el sistema")
            print("   Esto podría deberse a:")
            print("   - Dispositivo no conectado físicamente")
            print("   - Drivers no instalados correctamente")
            print("   - Problemas de permisos")
        else:
            for i, port in enumerate(ports, 1):
                print(f"   {i}. {port.device}")
                print(f"      Descripción: {port.description}")
                print(f"      HWID: {port.hwid}")
                print(f"      VID:PID: {port.vid}:{port.pid}")
                print()
    except Exception as e:
        print(f"   Error al listar puertos seriales: {str(e)}")

    # 2. Verificar win32print
    print("2. WIN32PRINT:")
    print("-" * 40)
    if WIN32_AVAILABLE:
        print("   ✓ win32print está disponible")
        try:
            printers = [printer[2] for printer in win32print.EnumPrinters(win32print.PRINTER_ENUM_LOCAL | win32print.PRINTER_ENUM_CONNECTIONS)]
            print(f"   Impresoras instaladas: {len(printers)}")
            for p in printers:
                marker = " ← TSC TX200" if "TSC" in p and "TX200" in p else ""
                print(f"   - {p}{marker}")
        except Exception as e:
            print(f"   Error obteniendo impresoras: {str(e)}")
    else:
        print("   ✗ win32print no está disponible")
        print("   Instala con: pip install pywin32")

    print("\n" + "=" * 60)

# Endpoint para diagnóstico
@app.route('/diagnostico', methods=['GET'])
def endpoint_diagnostico():
    """Endpoint para diagnóstico de puertos"""
    import io
    import sys

    # Capturar la salida del diagnóstico
    old_stdout = sys.stdout
    sys.stdout = buffer = io.StringIO()

    try:
        diagnosticar_puertos()
        output = buffer.getvalue()
    finally:
        sys.stdout = old_stdout

    return jsonify({'status': 'success', 'diagnostico': output})

import argparse

def start_ngrok_tunnel():
    """Inicia el túnel ngrok para exponer el servidor local"""
    try:
        # Iniciar ngrok en segundo plano para exponer el puerto 5000 con subdominio específico
        # Usar el comando correcto para ngrok con subdominio personalizado
        ngrok_process = subprocess.Popen(['ngrok', 'http', '--domain=pregeological-nonidentical-ines.ngrok-free.app', '5000'])

        # Esperar un momento para que ngrok inicie
        time.sleep(3)

        # Registrar la función para terminar ngrok cuando el script termine
        def cleanup():
            ngrok_process.terminate()
            ngrok_process.wait()

        atexit.register(cleanup)

        print("✓ Túnel ngrok iniciado exitosamente")
        logger.info("Túnel ngrok iniciado exitosamente")
        print("✓ Abriendo navegador con la URL pública...")
        logger.info("Abriendo navegador con la URL pública...")

        # Abrir el navegador con la URL del cliente
        webbrowser.open('https://75b43b34e0a2.ngrok-free.app')

        return ngrok_process

    except FileNotFoundError:
        logger.error("✗ ngrok no encontrado. Asegúrate de tener ngrok instalado y en el PATH.")
        logger.error("   Puedes descargarlo desde: https://ngrok.com/download")
        return None
    except Exception as e:
        logger.error(f"✗ Error iniciando túnel ngrok: {str(e)}")
        return None

# Servidor de desarrollo con auto-reload
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Servidor Flask para comunicación serial.')
    parser.add_argument('--port', type=str, default='COM3', help='Puerto serial')
    parser.add_argument('--baudrate', type=int, default=115200, help='Baud rate')
    parser.add_argument('--parity', type=str, default='N', help='Paridad (N, E, O)')
    parser.add_argument('--stopbits', type=int, default=1, help='Bits de parada')
    parser.add_argument('--bytesize', type=int, default=8, help='Bits de datos')
    parser.add_argument('--diagnostico', action='store_true', help='Ejecutar diagnóstico de puertos y salir')
    args = parser.parse_args()

    if args.diagnostico:
        diagnosticar_puertos()
        sys.exit(0)

    scale_manager.port = args.port
    scale_manager.baudrate = args.baudrate
    scale_manager.parity = args.parity
    scale_manager.stopbits = args.stopbits
    scale_manager.bytesize = args.bytesize

    # Mostrar información de inicio mejorada
    print("\n" + "="*70)
    print("🚀 INICIANDO SERVIDOR DE COMUNICACIÓN SERIAL")
    print("="*70)
    logger.info("Servidor Flask para Comunicación Serial")
    logger.info("Compatible con TSC TX200 (win32print) y báscula serial")
    logger.info("Con WebSocket para streaming de peso en tiempo real")
    logger.info("Optimizado para operación continua y alta disponibilidad")
    print("="*70)

    print("\n📋 ENDPOINTS DISPONIBLES:")
    logger.info("  GET  /health     - Estado del servidor y métricas")
    logger.info("  GET  /metrics    - Métricas de rendimiento y sistema")
    logger.info("  GET  /ports      - Puertos seriales e impresoras disponibles")
    logger.info("  GET  /diagnostico - Diagnóstico completo de dispositivos")
    logger.info("  POST /connect    - Conectar a puerto serial")

    print("\n⚖️  BÁSCULA:")
    logger.info("  POST /scale/connect  - Conectar báscula")
    logger.info("  POST /scale/start    - Iniciar lectura continua")
    logger.info("  POST /scale/stop     - Detener lectura")
    logger.info("  GET  /scale/read    - Leer peso actual")
    logger.info("  GET  /scale/last    - Última lectura")
    logger.info("  GET  /scale/latest  - Lecturas recientes del buffer")

    print("\n🖨️  IMPRESORA TSC TX200:")
    logger.info("  POST /printer/connect - Conectar impresora")
    logger.info("  POST /printer/print   - Imprimir etiqueta")
    logger.info("  POST /printer/test    - Test de impresión")
    logger.info("  POST /printer/disconnect - Desconectar impresora")
    print("="*70)

    # Mostrar estado inicial de dispositivos
    print("🔍 Ejecutando diagnóstico inicial de dispositivos...")
    logger.info("Ejecutando diagnóstico inicial de dispositivos...")
    diagnosticar_puertos()
    print("✅ Diagnóstico inicial completado")
    logger.info("Diagnóstico inicial completado")
    print("="*70 + "\n")

    logger.info("Ejecutando diagnóstico de puertos...")
    diagnosticar_puertos()
    logger.info("Fin del diagnóstico.")

    # Iniciar el túnel ngrok en un hilo separado después de que Flask esté listo
    def start_ngrok_after_flask():
        time.sleep(2)  # Esperar a que Flask inicie
        start_ngrok_tunnel()

    # Iniciar Flask en un hilo separado para poder iniciar ngrok después
    flask_thread = threading.Thread(target=lambda: socketio.run(app, host='0.0.0.0', port=5000, allow_unsafe_werkzeug=True))
    flask_thread.daemon = True
    flask_thread.start()

    # Iniciar ngrok después de que Flask esté listo
    start_ngrok_after_flask()

    # Mantener el hilo principal vivo
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        logger.info("Cerrando servidor...")
        sys.exit(0)