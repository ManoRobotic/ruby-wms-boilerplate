#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Servidor Flask para comunicación serial con báscula e impresora
Integra el script de báscula existente con endpoints REST
"""

import argparse
from flask import Flask, request, jsonify, render_template
from flask_cors import CORS
import threading
import time
import json
import serial
import serial.tools.list_ports
import usb.core
import usb.util
from datetime import datetime
import csv
import os
import sys
import logging
import queue
import subprocess
from dataclasses import dataclass
from typing import Optional, Dict, Any

# Configurar logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configurar Flask con el directorio de plantillas
template_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'templates')
app = Flask(__name__, template_folder=template_dir)
CORS(app)

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
        
    def connect(self) -> bool:
        """Conecta a la báscula"""
        try:
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
            logger.info(f"✓ Conexión establecida en el puerto {self.port}")
            return True
            
        except serial.SerialException as e:
            logger.error(f"✗ Error de conexión serial: {str(e)}")
            return False
    
    def disconnect(self):
        """Desconecta la báscula"""
        if self.serial_connection and self.serial_connection.is_open:
            self.serial_connection.close()
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
        self.device = None
        self.endpoint_out = None
        self.endpoint_in = None
        
    def connect_usb_printer(self) -> bool:
        """Conecta con impresora TSC TX200 via USB usando tu código"""
        try:
            logger.info("Buscando impresora TSC TX200...")
            
            # Buscar dispositivo TSC TX200 (Vendor ID: 0x1203, Product ID: 0x0230)
            self.device = usb.core.find(idVendor=0x1203, idProduct=0x0230)
            
            if self.device is None:
                logger.warning("✗ Impresora TSC TX200 no encontrada")
                logger.warning("Verifica que esté conectada y encendida")
                return False
            
            logger.info(f"✓ Impresora encontrada: {self.device}")
            
            # Configurar dispositivo como en tu código
            if self.device.is_kernel_driver_active(0):
                logger.info("Desconectando driver del kernel...")
                self.device.detach_kernel_driver(0)
            
            # Establecer configuración
            self.device.set_configuration()
            
            # Obtener interface y endpoints
            cfg = self.device.get_active_configuration()
            intf = cfg[(0,0)]
            
            # Encontrar endpoints
            self.endpoint_out = usb.util.find_descriptor(
                intf,
                custom_match = lambda e: \
                    usb.util.endpoint_direction(e.bEndpointAddress) == \
                    usb.util.ENDPOINT_OUT
            )
            
            self.endpoint_in = usb.util.find_descriptor(
                intf,
                custom_match = lambda e: \
                    usb.util.endpoint_direction(e.bEndpointAddress) == \
                    usb.util.ENDPOINT_IN
            )
            
            if self.endpoint_out is None:
                logger.error("✗ No se encontró endpoint de salida")
                return False
            
            logger.info(f"✓ Endpoint OUT: {self.endpoint_out.bEndpointAddress}")
            if self.endpoint_in:
                logger.info(f"✓ Endpoint IN: {self.endpoint_in.bEndpointAddress}")
            
            logger.info("✓ Impresora conectada exitosamente!")
            return True
            
        except Exception as e:
            logger.error(f"✗ Error al configurar dispositivo: {str(e)}")
            return False
    
    def enviar_comando(self, comando: str) -> bool:
        """Envía comando TSPL2 a la impresora"""
        if not self.device or not self.endpoint_out:
            logger.error("✗ Dispositivo no conectado")
            return False
        
        try:
            # Convertir comando a bytes
            if isinstance(comando, str):
                comando = comando.encode('utf-8')
            
            # Enviar comando
            bytes_escritos = self.endpoint_out.write(comando)
            logger.debug(f"✓ Enviados {bytes_escritos} bytes: {comando.decode('utf-8').strip()}")
            return True
            
        except Exception as e:
            logger.error(f"✗ Error enviando comando: {str(e)}")
            return False
    
    def print_label(self, content: str, ancho_mm: int = 80, alto_mm: int = 50) -> bool:
        """Imprime etiqueta usando comandos exactos de scaner.py"""
        try:
            if not self.device or not self.endpoint_out:
                logger.error("✗ Impresora no conectada")
                return False
            
            logger.info(f"=== IMPRIMIENDO ETIQUETA ===")
            logger.info(f"Tamaño: {ancho_mm}x{alto_mm}mm")
            logger.info(f"Contenido: {content}")
            
            # Comandos TSPL2 exactos de tu scaner.py que funciona
            comandos = [
                f"SIZE {ancho_mm} mm, {alto_mm} mm\n",
                "GAP 2 mm, 0 mm\n",
                "DIRECTION 1,0\n",
                "REFERENCE 0,0\n",
                "OFFSET 0 mm\n",
                "SET PEEL OFF\n",
                "SET CUTTER OFF\n", 
                "SET PARTIAL_CUTTER OFF\n",
                "SET TEAR ON\n",
                "CLS\n",
                "CODEPAGE 1252\n",
                
                # Texto usando las mismas posiciones de scaner.py
                f"TEXT {int(ancho_mm*2)},{int(alto_mm*1.5)},\"4\",0,1,1,\"{content}\"\n",
                f"TEXT {int(ancho_mm*2)},{int(alto_mm*2.5)},\"2\",0,1,1,\"Peso: --kg\"\n",
                
                # Línea de separación
                f"BAR {int(ancho_mm*1.5)},{int(alto_mm*4.5)},{int(ancho_mm*5)},2\n",
                
                # Fecha/hora
                f"TEXT {int(ancho_mm*2)},{int(alto_mm*5.5)},\"1\",0,1,1,\"{time.strftime('%Y-%m-%d %H:%M')}\"\n",
                
                "PRINT 1,1\n"
            ]
            
            # Enviar cada comando con logging detallado
            for i, comando in enumerate(comandos, 1):
                logger.info(f"Enviando comando {i}: {comando.strip()}")
                if not self.enviar_comando(comando):
                    logger.error(f"Falló comando {i}: {comando.strip()}")
                    return False
                time.sleep(0.1)  # Pausa entre comandos como en scaner.py
            
            logger.info("✓ Etiqueta enviada a impresora correctamente")
            return True
                
        except Exception as e:
            logger.error(f"Error imprimiendo: {str(e)}")
            return False
    
    def test_impresora(self, ancho_mm: int = 80, alto_mm: int = 50) -> bool:
        """Test básico usando comandos exactos de scaner.py"""
        try:
            if not self.device or not self.endpoint_out:
                logger.error("✗ Dispositivo no conectado")
                return False
                
            logger.info("=== TEST DE IMPRESORA ===")
            logger.info(f"Configurando para papel: {ancho_mm}mm x {alto_mm}mm")
            
            # Comandos de test exactos de tu scaner.py
            comandos_test = [
                f"SIZE {ancho_mm} mm, {alto_mm} mm\n",     # Tamaño del papel
                "GAP 2 mm, 0 mm\n",                       # Espacio entre etiquetas  
                "DIRECTION 1,0\n",                        # Dirección normal
                "REFERENCE 0,0\n",                        # Punto de referencia en esquina
                "OFFSET 0 mm\n",                          # Sin offset
                "SET PEEL OFF\n",                         # Modo peeling desactivado
                "SET CUTTER OFF\n",                       # Cortador desactivado
                "SET PARTIAL_CUTTER OFF\n",               # Cortador parcial desactivado
                "SET TEAR ON\n",                          # Modo tear activado
                "CLS\n",                                  # Limpiar buffer de impresión
                "CODEPAGE 1252\n",                        # Página de códigos occidental
                
                # Texto centrado y bien posicionado como en scaner.py
                f"TEXT {int(ancho_mm*2)},{int(alto_mm*1.5)},\"4\",0,1,1,\"TSC TX200 TEST\"\n",
                f"TEXT {int(ancho_mm*2)},{int(alto_mm*2.5)},\"3\",0,1,1,\"Papel: {ancho_mm}x{alto_mm}mm\"\n",
                f"TEXT {int(ancho_mm*2)},{int(alto_mm*3.5)},\"2\",0,1,1,\"Configuracion OK!\"\n",
                
                # Línea de separación
                f"BAR {int(ancho_mm*1.5)},{int(alto_mm*4.5)},{int(ancho_mm*5)},2\n",
                
                # Información de fecha/hora
                f"TEXT {int(ancho_mm*2)},{int(alto_mm*5.5)},\"1\",0,1,1,\"{time.strftime('%Y-%m-%d %H:%M')}\"\n",
                
                "PRINT 1,1\n"                             # Imprimir 1 copia
            ]
            
            logger.info("Enviando comandos de test...")
            for i, comando in enumerate(comandos_test, 1):
                logger.info(f"{i:2d}. {comando.strip()}")
                if self.enviar_comando(comando):
                    time.sleep(0.1)  # Pequeña pausa entre comandos
                else:
                    logger.error(f"✗ Error enviando comando {i}: {comando.strip()}")
                    return False
            
            logger.info(f"✓ Test completado para papel {ancho_mm}x{alto_mm}mm")
            logger.info("La etiqueta debería salir completa y centrada.")
            return True
            
        except Exception as e:
            logger.error(f"Error en test de impresora: {str(e)}")
            return False
    
    def disconnect(self):
        """Desconecta de la impresora"""
        if self.device:
            try:
                usb.util.dispose_resources(self.device)
                logger.info("✓ Desconectado de la impresora")
            except Exception as e:
                logger.warning(f"Error desconectando: {str(e)}")
            finally:
                self.device = None
                self.endpoint_out = None
                self.endpoint_in = None

# Instancias globales
scale_manager = ScaleManager()
printer_manager = PrinterManager()

# Endpoints REST
@app.route('/')
def index():
    """Página principal del monitor serial"""
    return render_template('index.html')

@app.route('/health', methods=['GET'])
def health_check():
    """Endpoint de salud del servidor"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'services': {
            'scale': scale_manager.is_running,
            'printer': printer_manager.device is not None
        }
    })

@app.route('/scale/connect', methods=['POST'])
def connect_scale():
    """Conecta a la báscula"""
    data = request.get_json() or {}
    port = data.get('port', 'COM3')
    baudrate = data.get('baudrate', 115200)
    
    scale_manager.port = port
    scale_manager.baudrate = baudrate
    
    if scale_manager.connect():
        return jsonify({'status': 'success', 'message': 'Báscula conectada'})
    else:
        return jsonify({'status': 'error', 'message': 'Error conectando báscula'}), 500

@app.route('/scale/disconnect', methods=['POST'])
def disconnect_scale():
    """Desconecta la báscula"""
    scale_manager.stop_continuous_reading()
    scale_manager.disconnect()
    return jsonify({'status': 'success', 'message': 'Báscula desconectada'})

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
    """Conecta a la impresora"""
    if printer_manager.connect_usb_printer():
        return jsonify({'status': 'success', 'message': 'Impresora conectada'})
    else:
        return jsonify({'status': 'error', 'message': 'Error conectando impresora'}), 500

@app.route('/printer/print', methods=['POST'])
def print_label():
    """Imprime etiqueta"""
    data = request.get_json()
    if not data or 'content' not in data:
        return jsonify({'status': 'error', 'message': 'Contenido requerido'}), 400
    
    content = data['content']
    ancho_mm = data.get('ancho_mm', 80)
    alto_mm = data.get('alto_mm', 50)
    
    if printer_manager.print_label(content, ancho_mm, alto_mm):
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
    """Lista puertos seriales disponibles"""
    ports = []
    for port in serial.tools.list_ports.comports():
        ports.append({
            'device': port.device,
            'description': port.description,
            'hwid': port.hwid
        })
    
    return jsonify({'status': 'success', 'ports': ports})

import argparse

# ... (existing imports)

# ... (existing code)

# Servidor de desarrollo con auto-reload
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Servidor Flask para comunicación serial.')
    parser.add_argument('--port', type=str, default='COM3', help='Puerto serial')
    parser.add_argument('--baudrate', type=int, default=115200, help='Baud rate')
    parser.add_argument('--parity', type=str, default='N', help='Paridad (N, E, O)')
    parser.add_argument('--stopbits', type=int, default=1, help='Bits de parada')
    parser.add_argument('--bytesize', type=int, default=8, help='Bits de datos')
    args = parser.parse_args()

    scale_manager.port = args.port
    scale_manager.baudrate = args.baudrate
    scale_manager.parity = args.parity
    scale_manager.stopbits = args.stopbits
    scale_manager.bytesize = args.bytesize

    logger.info("=== Servidor Flask para Comunicación Serial ===")
    logger.info("Compatible con TSC TX200 y báscula serial")
    logger.info("===============================================")
    logger.info("Endpoints disponibles:")
    logger.info("  GET  /health - Estado del servidor")
    logger.info("  GET  /ports - Puertos seriales disponibles")
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
    logger.info("  POST /printer/connect - Conectar impresora USB")
    logger.info("  POST /printer/print - Imprimir etiqueta")
    logger.info("  POST /printer/test - Test de impresión")
    logger.info("  POST /printer/disconnect - Desconectar impresora")
    logger.info("===============================================")
    
    app.run(host='0.0.0.0', port=5000, debug=True)
