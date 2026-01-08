#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Servidor Flask para comunicación serial con báscula e impresora
Versión modificada para Windows con soporte para win32print y WebSockets
"""

import argparse
from flask import Flask, request, jsonify, render_template
from flask_cors import CORS
from flask_socketio import SocketIO, emit, Namespace
import threading
import time
import json
import serial
import serial.tools.list_ports
import win32print
import win32api
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

# Configurar logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configurar Flask con el directorio de plantillas
template_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'templates')
app = Flask(__name__, template_folder=template_dir)

# Configurar CORS para dominios específicos
cors_origins = [
    'http://localhost:3000',
    'https://wmsys.fly.dev',
    '*.ngrok-free.app'
]
CORS(app, origins=cors_origins)

# Configurar SocketIO
socketio = SocketIO(app, cors_allowed_origins=cors_origins, allow_unsafe_werkzeug=True)

# Variables globales
scale_data_queue = queue.Queue()
server_connected = False
connection_lock = threading.Lock()
scale_thread = None
scale_running = False

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

    def connect(self) -> bool:
        """Conecta a la báscula"""
        try:
            # Verificar si ya está conectado
            if self.serial_connection and self.serial_connection.is_open:
                logger.info(f"Báscula ya conectada en {self.port}")
                return True

            # Mostrar puertos disponibles
            available_ports = serial.tools.list_ports.comports()
            logger.info("Puertos seriales disponibles:")
            for port in available_ports:
                logger.info(f"  - {port.device}")

            self.serial_connection = serial.Serial(
                self.port,
                baudrate=self.baudrate,
                timeout=1,
                parity=self.parity,
                stopbits=self.stopbits,
                bytesize=self.bytesize
            )
            self.connected = True
            logger.info(f"✓ Conexión establecida en el puerto {self.port}")
            return True

        except serial.SerialException as e:
            logger.error(f"✗ Error de conexión serial: {str(e)}")
            return False

    def disconnect(self):
        """Desconecta la báscula"""
        if self.serial_connection and self.serial_connection.is_open:
            self.serial_connection.close()
            self.connected = False
            logger.info("✓ Puerto serial cerrado correctamente")

    def read_weight(self, timeout=5) -> Optional[ScaleReading]:
        """Lee un peso de la báscula, con un timeout"""
        if not self.serial_connection or not self.serial_connection.is_open:
            logger.error("La conexión serial no está abierta.")
            return None

        try:
            logger.info("Esperando datos de la báscula...")
            start_time = time.time()
            while time.time() - start_time < timeout:
                if self.serial_connection.in_waiting > 0:
                    data = self.serial_connection.readline().decode('utf-8', errors='ignore').strip()
                    logger.info(f"Datos recibidos: '{data}'")

                    if data:
                        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

                        reading = ScaleReading(weight=data, timestamp=timestamp)
                        self.last_reading = reading

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

                        # Print to console immediately when data is received
                        print(f"\033[92m[{timestamp}]\033[0m Peso: \033[93m{data}\033[0m")

                        return reading
                time.sleep(0.1)

            logger.warning("No se recibieron datos en el tiempo esperado.")

        except Exception as e:
            logger.error(f"Error leyendo báscula: {str(e)}")

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
        """Inicia lectura continua en hilo separado"""
        self.is_running = True

        def read_loop():
            while self.is_running:
                reading = self.read_weight()
                if reading:
                    scale_data_queue.put(reading)
                    # Print to console with colored output
                    print(f"\033[92m[{reading.timestamp}]\033[0m Peso: \033[93m{reading.weight}\033[0m")
                time.sleep(0.1)

        thread = threading.Thread(target=read_loop, daemon=True)
        thread.start()
        logger.info("✓ Lectura continua iniciada")

    def stop_continuous_reading(self):
        """Detiene lectura continua"""
        self.is_running = False
        logger.info("✓ Lectura continua detenida")

class PrinterManager:
    def __init__(self):
        self.printer_name = None
        self.printer_handle = None
        self.is_connected = False

    def connect_printer(self) -> bool:
        """Verifica que la impresora TSC TX200 esté disponible usando win32print"""
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
            logger.info(f"✓ Impresora disponible: {self.printer_name}")
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
                logger.info("✓ Desconectado de la impresora")
            except Exception as e:
                logger.error(f"Error desconectando: {str(e)}")

    def print_label(self, content: str, ancho_mm: int = 80, alto_mm: int = 50) -> bool:
        """Imprime etiqueta usando el comando copy de Windows"""
        try:
            import subprocess
            import tempfile
            import os

            # Obtener el nombre de la impresora
            printers = [printer[2] for printer in win32print.EnumPrinters(win32print.PRINTER_ENUM_LOCAL | win32print.PRINTER_ENUM_CONNECTIONS)]
            tsc_printers = [p for p in printers if 'TSC' in p.upper() and 'TX200' in p.upper()]
            
            if not tsc_printers:
                logger.error("✗ No se encontró la impresora TSC TX200")
                return False

            printer_name = tsc_printers[0]
            logger.info(f"=== IMPRIMIENDO ETIQUETA CON COMANDO COPY ===")
            logger.info(f"Tamaño: {ancho_mm}x{alto_mm}mm")
            logger.info(f"Enviando a impresora: {printer_name}")

            # Crear archivo temporal con el contenido TSPL
            with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.prn', encoding='utf-8') as temp_file:
                temp_file.write(content)
                temp_filename = temp_file.name

            logger.info(f"Archivo temporal creado: {temp_filename}")
            
            try:
                # Usar el comando print de Windows para enviar directamente a la impresora
                # Este comando sabemos que funciona con éxito
                cmd = f'print /D:"{printer_name}" "{temp_filename}"'
                logger.info(f"Ejecutando comando: {cmd}")

                result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
                
                logger.info(f"Código de retorno: {result.returncode}")
                if result.stdout:
                    logger.info(f"Salida estándar: {result.stdout}")
                if result.stderr:
                    logger.info(f"Error estándar: {result.stderr}")
                
                if result.returncode == 0 or "1 file(s) copied" in result.stdout:
                    logger.info("✓ Comando copy ejecutado exitosamente")
                    # Esperar un poco más para que se procese la impresión
                    import time
                    time.sleep(2)
                    return True
                else:
                    logger.error(f"✗ Error en comando copy: {result.stderr}")
                    return False
            finally:
                # Esperar antes de eliminar el archivo para asegurar que se haya impreso
                import time
                time.sleep(3)  # Esperar más tiempo antes de eliminar
                try:
                    os.unlink(temp_filename)
                    logger.info(f"Archivo temporal eliminado: {temp_filename}")
                except Exception as e:
                    logger.warning(f"No se pudo eliminar archivo temporal: {e}")

        except Exception as e:
            logger.error(f"✗ Error imprimiendo: {str(e)}")
            import traceback
            logger.error(f"Detalle del error: {traceback.format_exc()}")
            return False

    def print_label_with_config(self, content: str, ancho_mm: int = 80, alto_mm: int = 50) -> bool:
        """Imprime etiqueta sin modificar configuración de la impresora"""
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
        logger.info("Cliente WebSocket conectado al namespace /weight")
        emit('connected', {'data': 'Conectado al stream de peso'})

    def on_disconnect(self):
        logger.info("Cliente WebSocket desconectado del namespace /weight")

socketio.on_namespace(WeightNamespace('/weight'))

# Endpoints REST
@app.route('/')
def index():
    """Página principal del monitor serial"""
    return render_template('index.html')

@app.route('/health', methods=['GET'])
def health_check():
    """Endpoint de salud del servidor detallado"""
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
    """Obtiene lecturas más recientes de la cola"""
    readings = []
    try:
        while not scale_data_queue.empty():
            reading = scale_data_queue.get_nowait()
            readings.append({
                'weight': reading.weight,
                'timestamp': reading.timestamp,
                'status': reading.status
            })
            # También imprimir en consola para debugging
            print(f"\033[94m[API REQUEST]\033[0m [{reading.timestamp}] Peso: \033[93m{reading.weight}\033[0m")
    except queue.Empty:
        pass

    return jsonify({'status': 'success', 'readings': readings})

@app.route('/printer/connect', methods=['POST'])
def connect_printer():
    """Conecta a la impresora con soporte idempotente"""
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

    logger.info(f"Total de dispositivos encontrados: {len(ports)}")
    return jsonify({'status': 'success', 'ports': ports, 'total': len(ports)})

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
    try:
        printers = [printer[2] for printer in win32print.EnumPrinters(win32print.PRINTER_ENUM_LOCAL | win32print.PRINTER_ENUM_CONNECTIONS)]
        print(f"   Impresoras instaladas: {len(printers)}")
        for p in printers:
            marker = " ← TSC TX200" if "TSC" in p and "TX200" in p else ""
            print(f"   - {p}{marker}")
    except Exception as e:
        print(f"   Error obteniendo impresoras: {str(e)}")

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

        logger.info("✓ Túnel ngrok iniciado exitosamente")
        logger.info("✓ Abriendo navegador con la URL pública...")

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

    logger.info("=== Servidor Flask para Comunicación Serial ===")
    logger.info("Compatible con TSC TX200 (win32print) y báscula serial")
    logger.info("Con WebSocket para streaming de peso")
    logger.info("===============================================")
    logger.info("Endpoints disponibles:")
    logger.info("  GET  /health - Estado del servidor")
    logger.info("  GET  /ports - Puertos seriales disponibles")
    logger.info("  GET  /diagnostico - Diagnóstico completo de puertos y dispositivos")
    logger.info("  POST /connect - Conectar a puerto serial")
    logger.info("")
    logger.info("BÁSCULA:")
    logger.info("  POST /scale/connect - Conectar báscula")
    logger.info("  POST /scale/start - Iniciar lectura continua")
    logger.info("  POST /scale/stop - Detener lectura")
    logger.info("  GET  /scale/read - Leer peso actual")
    logger.info("  GET  /scale/last - Última lectura")
    logger.info("  GET  /scale/latest - Lecturas de la cola")
    logger.info("  GET  /scale/get_weight_now - Obtener peso con timeout")
    logger.info("")
    logger.info("IMPRESORA TSC TX200:")
    logger.info("  POST /printer/connect - Conectar impresora (win32print)")
    logger.info("  POST /printer/print - Imprimir etiqueta")
    logger.info("  POST /printer/test - Test de impresión")
    logger.info("  POST /printer/disconnect - Desconectar impresora")
    logger.info("===============================================")

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