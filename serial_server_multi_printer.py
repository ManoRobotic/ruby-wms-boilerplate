#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Servidor Flask para comunicación serial con báscula e impresora
Versión modificada para soportar múltiples tipos de impresoras:
- TSC TX200 (USB directo)
- Zebra (Windows Printer o USB serial)
"""
import argparse
from flask import Flask, request, jsonify
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

app = Flask(__name__)

# Configurar CORS para permitir acceso desde el servidor de producción
CORS(app, origins=[
    "https://wmsys.fly.dev",
    "http://localhost:3000",  # Para desarrollo local
    "http://127.0.0.1:3000"   # Para desarrollo local
])

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
    
    def read_weight(self) -> Optional[ScaleReading]:
        """Lee un peso de la báscula"""
        if not self.serial_connection or not self.serial_connection.is_open:
            return None
            
        try:
            if self.serial_connection.in_waiting > 0:
                data = self.serial_connection.readline().decode().strip()
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                
                reading = ScaleReading(weight=data, timestamp=timestamp)
                self.last_reading = reading
                
                # Escribir a CSV
                self._save_to_csv(reading)
                
                return reading
                
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
                    logger.info(f"[{reading.timestamp}] Peso: {reading.weight}")
                time.sleep(0.1)
        
        thread = threading.Thread(target=read_loop, daemon=True)
        thread.start()
        logger.info("✓ Lectura continua iniciada")
        
    def stop_continuous_reading(self):
        """Detiene lectura continua"""
        self.is_running = False
        logger.info("✓ Lectura continua detenida")

class TSCPrinterManager:
    """Manejador para impresora TSC TX200 via USB directo"""
    def __init__(self):
        self.device = None
        self.endpoint_out = None
        self.endpoint_in = None
        self.vendor_id = 0x1203
        self.product_id = 0x0230
        
    def connect_usb_printer(self) -> bool:
        """Conecta con impresora TSC TX200 via USB"""
        try:
            logger.info("Buscando impresora TSC TX200...")
            
            # Buscar dispositivo TSC TX200
            self.device = usb.core.find(idVendor=self.vendor_id, idProduct=self.product_id)
            
            if self.device is None:
                logger.warning("✗ Impresora TSC TX200 no encontrada")
                logger.warning("Verifica que esté conectada y encendida")
                return False
            
            logger.info(f"✓ Impresora encontrada: {self.device}")
            
            # Configurar dispositivo
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
            
            logger.info("✓ Impresora TSC conectada exitosamente!")
            return True
            
        except Exception as e:
            logger.error(f"✗ Error al configurar dispositivo TSC: {str(e)}")
            return False
    
    def enviar_comando(self, comando: str) -> bool:
        """Envía comando TSPL2 a la impresora"""
        if not self.device or not self.endpoint_out:
            logger.error("✗ Dispositivo TSC no conectado")
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
            logger.error(f"✗ Error enviando comando TSC: {str(e)}")
            return False
    
    def print_label(self, content: str, ancho_mm: int = 80, alto_mm: int = 50) -> bool:
        """Imprime etiqueta usando comandos TSPL2"""
        try:
            if not self.device or not self.endpoint_out:
                logger.error("✗ Impresora TSC no conectada")
                return False
            
            logger.info(f"=== IMPRIMIENDO ETIQUETA TSC ===")
            logger.info(f"Tamaño: {ancho_mm}x{alto_mm}mm")
            logger.info(f"Contenido: {content}")
            
            # Comandos TSPL2
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
                
                # Texto
                f"TEXT {int(ancho_mm*2)},{int(alto_mm*1.5)},\"4\",0,1,1,\"{content}\"\n",
                f"TEXT {int(ancho_mm*2)},{int(alto_mm*2.5)},\"2\",0,1,1,\"Peso: --kg\"\n",
                
                # Línea de separación
                f"BAR {int(ancho_mm*1.5)},{int(alto_mm*4.5)},{int(ancho_mm*5)},2\n",
                
                # Fecha/hora
                f"TEXT {int(ancho_mm*2)},{int(alto_mm*5.5)},\"1\",0,1,1,\"{time.strftime('%Y-%m-%d %H:%M')}\"\n",
                
                "PRINT 1,1\n"
            ]
            
            # Enviar cada comando
            for i, comando in enumerate(comandos, 1):
                logger.info(f"Enviando comando {i}: {comando.strip()}")
                if not self.enviar_comando(comando):
                    logger.error(f"Falló comando {i}: {comando.strip()}")
                    return False
                time.sleep(0.1)
            
            logger.info("✓ Etiqueta TSC enviada a impresora correctamente")
            return True
                
        except Exception as e:
            logger.error(f"Error imprimiendo con TSC: {str(e)}")
            return False
    
    def test_impresora(self, ancho_mm: int = 80, alto_mm: int = 50) -> bool:
        """Test básico usando comandos TSPL2"""
        try:
            if not self.device or not self.endpoint_out:
                logger.error("✗ Dispositivo TSC no conectado")
                return False
                
            logger.info("=== TEST DE IMPRESORA TSC ===")
            logger.info(f"Configurando para papel: {ancho_mm}mm x {alto_mm}mm")
            
            # Comandos de test
            comandos_test = [
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
                
                # Texto centrado
                f"TEXT {int(ancho_mm*2)},{int(alto_mm*1.5)},\"4\",0,1,1,\"TSC TX200 TEST\"\n",
                f"TEXT {int(ancho_mm*2)},{int(alto_mm*2.5)},\"3\",0,1,1,\"Papel: {ancho_mm}x{alto_mm}mm\"\n",
                f"TEXT {int(ancho_mm*2)},{int(alto_mm*3.5)},\"2\",0,1,1,\"Configuracion OK!\"\n",
                
                # Línea de separación
                f"BAR {int(ancho_mm*1.5)},{int(alto_mm*4.5)},{int(ancho_mm*5)},2\n",
                
                # Información de fecha/hora
                f"TEXT {int(ancho_mm*2)},{int(alto_mm*5.5)},\"1\",0,1,1,\"{time.strftime('%Y-%m-%d %H:%M')}\"\n",
                
                "PRINT 1,1\n"
            ]
            
            logger.info("Enviando comandos de test...")
            for i, comando in enumerate(comandos_test, 1):
                logger.info(f"{i:2d}. {comando.strip()}")
                if self.enviar_comando(comando):
                    time.sleep(0.1)
                else:
                    logger.error(f"✗ Error enviando comando {i}: {comando.strip()}")
                    return False
            
            logger.info(f"✓ Test TSC completado para papel {ancho_mm}x{alto_mm}mm")
            logger.info("La etiqueta debería salir completa y centrada.")
            return True
            
        except Exception as e:
            logger.error(f"Error en test de impresora TSC: {str(e)}")
            return False
    
    def disconnect(self):
        """Desconecta de la impresora TSC"""
        if self.device:
            try:
                usb.util.dispose_resources(self.device)
                logger.info("✓ Desconectado de la impresora TSC")
            except Exception as e:
                logger.warning(f"Error desconectando TSC: {str(e)}")
            finally:
                self.device = None
                self.endpoint_out = None
                self.endpoint_in = None

class ZebraPrinterManager:
    """Manejador para impresora Zebra (Windows Printer o USB serial)"""
    def __init__(self):
        self.printer_name = "ZDesigner ZD421-203dpi ZPL"  # Valor por defecto
        self.serial_port = None
        self.serial_connection = None
        self.is_windows = os.name == 'nt'  # True si es Windows
        
    def connect_windows_printer(self, printer_name: str = None) -> bool:
        """Conecta con impresora Zebra en Windows usando win32print"""
        if not self.is_windows:
            logger.error("✗ Esta función solo está disponible en Windows")
            return False
            
        try:
            import win32print
            import win32api
            
            if printer_name:
                self.printer_name = printer_name
                
            logger.info(f"Buscando impresora Zebra: {self.printer_name}")
            
            # Verificar si la impresora existe
            printers = [printer[2] for printer in win32print.EnumPrinters(
                win32print.PRINTER_ENUM_LOCAL | win32print.PRINTER_ENUM_CONNECTIONS)]
            
            if self.printer_name not in printers:
                logger.warning(f"✗ Impresora '{self.printer_name}' no encontrada")
                logger.info("Impresoras disponibles:")
                for i, printer in enumerate(printers, 1):
                    logger.info(f"   {i}. {printer}")
                return False
            
            logger.info(f"✓ Impresora Zebra encontrada: {self.printer_name}")
            return True
            
        except ImportError:
            logger.error("✗ win32print no está disponible. Instala pywin32")
            return False
        except Exception as e:
            logger.error(f"✗ Error conectando con impresora Zebra Windows: {str(e)}")
            return False
    
    def connect_serial_printer(self, port: str, baudrate: int = 9600) -> bool:
        """Conecta con impresora Zebra via puerto serial"""
        try:
            logger.info(f"Conectando a impresora Zebra en puerto serial: {port}")
            
            self.serial_connection = serial.Serial(
                port, 
                baudrate=baudrate, 
                timeout=1,
                parity='N',
                stopbits=1,
                bytesize=8
            )
            
            logger.info(f"✓ Conexión serial establecida con impresora Zebra en {port}")
            self.serial_port = port
            return True
            
        except serial.SerialException as e:
            logger.error(f"✗ Error de conexión serial con impresora Zebra: {str(e)}")
            return False
        except Exception as e:
            logger.error(f"✗ Error conectando con impresora Zebra serial: {str(e)}")
            return False
    
    def enviar_comando_zpl(self, comando: str) -> bool:
        """Envía comando ZPL a la impresora"""
        try:
            if self.is_windows and self.printer_name:
                # Usar win32print para impresora Windows
                import win32print
                
                hPrinter = win32print.OpenPrinter(self.printer_name)
                try:
                    hJob = win32print.StartDocPrinter(hPrinter, 1, ("Etiqueta Zebra", None, "RAW"))
                    win32print.StartPagePrinter(hPrinter)
                    win32print.WritePrinter(hPrinter, comando.encode("utf-8"))
                    win32print.EndPagePrinter(hPrinter)
                    win32print.EndDocPrinter(hPrinter)
                    logger.debug(f"✓ Comando ZPL enviado a impresora Windows: {comando.strip()}")
                    return True
                finally:
                    win32print.ClosePrinter(hPrinter)
            
            elif self.serial_connection and self.serial_connection.is_open:
                # Usar conexión serial
                if isinstance(comando, str):
                    comando = comando.encode('utf-8')
                
                bytes_escritos = self.serial_connection.write(comando)
                self.serial_connection.flush()
                logger.debug(f"✓ Enviados {bytes_escritos} bytes a impresora Zebra serial: {comando.decode('utf-8').strip()}")
                return True
            
            else:
                logger.error("✗ No hay conexión activa con impresora Zebra")
                return False
                
        except Exception as e:
            logger.error(f"✗ Error enviando comando ZPL: {str(e)}")
            return False
    
    def print_label(self, content: str, ancho_mm: int = 80, alto_mm: int = 50) -> bool:
        """Imprime etiqueta usando comandos ZPL"""
        try:
            logger.info(f"=== IMPRIMIENDO ETIQUETA ZEBRA ===")
            logger.info(f"Contenido: {content}")
            
            # Comandos ZPL básicos
            zpl_commands = f"""
^XA
^CI28
^MMT
^PW{ancho_mm * 8}  ; Ancho en puntos (aproximación)
^LL{alto_mm * 8}  ; Alto en puntos (aproximación)
^LS0
^FO50,50^A0N,40,40^FD{content}^FS
^FO50,100^A0N,30,30^FDPeso: --kg^FS
^FO50,150^A0N,25,25^FD{time.strftime('%Y-%m-%d %H:%M')}^FS
^PQ1,0,1,Y
^XZ
"""
            
            if self.enviar_comando_zpl(zpl_commands):
                logger.info("✓ Etiqueta Zebra enviada a impresora correctamente")
                return True
            else:
                logger.error("✗ Error enviando etiqueta Zebra")
                return False
                
        except Exception as e:
            logger.error(f"Error imprimiendo con Zebra: {str(e)}")
            return False
    
    def test_impresora(self, ancho_mm: int = 80, alto_mm: int = 50) -> bool:
        """Test básico de impresora Zebra"""
        try:
            logger.info("=== TEST DE IMPRESORA ZEBRA ===")
            
            # Comando de test ZPL
            test_zpl = f"""
^XA
^CI28
^MMT
^PW{ancho_mm * 8}
^LL{alto_mm * 8}
^LS0
^FO100,50^A0N,50,50^FDZEBRA TEST^FS
^FO100,120^A0N,35,35^FDPapel: {ancho_mm}x{alto_mm}mm^FS
^FO100,170^A0N,30,30^FDConfiguracion OK!^FS
^FO100,220^A0N,25,25^FD{time.strftime('%Y-%m-%d %H:%M')}^FS
^FO50,270^GB300,1,1^FS  ; Línea
^PQ1,0,1,Y
^XZ
"""
            
            if self.enviar_comando_zpl(test_zpl):
                logger.info("✓ Test Zebra completado")
                logger.info("La etiqueta debería salir correctamente.")
                return True
            else:
                logger.error("✗ Error en test Zebra")
                return False
                
        except Exception as e:
            logger.error(f"Error en test de impresora Zebra: {str(e)}")
            return False
    
    def disconnect(self):
        """Desconecta de la impresora Zebra"""
        if self.serial_connection and self.serial_connection.is_open:
            self.serial_connection.close()
            logger.info("✓ Conexión serial Zebra cerrada")
        
        self.serial_connection = None
        self.serial_port = None
        logger.info("✓ Desconectado de la impresora Zebra")

class MultiPrinterManager:
    """Manejador unificado para múltiples tipos de impresoras"""
    def __init__(self):
        self.tsc_printer = TSCPrinterManager()
        self.zebra_printer = ZebraPrinterManager()
        self.current_printer_type = None  # 'tsc' o 'zebra'
        
    def auto_detect_printer(self) -> str:
        """Detecta automáticamente qué tipo de impresora está conectada"""
        logger.info("Detectando tipo de impresora...")
        
        # Primero intentar detectar TSC
        tsc_device = usb.core.find(idVendor=0x1203, idProduct=0x0230)
        if tsc_device is not None:
            logger.info("✓ Impresora TSC TX200 detectada")
            return 'tsc'
        
        # Luego intentar detectar Zebra (en Windows)
        if os.name == 'nt':
            try:
                import win32print
                printers = [printer[2] for printer in win32print.EnumPrinters(
                    win32print.PRINTER_ENUM_LOCAL | win32print.PRINTER_ENUM_CONNECTIONS)]
                
                zebra_printers = [p for p in printers if 'zebra' in p.lower() or 'zd' in p.lower()]
                if zebra_printers:
                    logger.info(f"✓ Impresora Zebra detectada: {zebra_printers[0]}")
                    self.zebra_printer.printer_name = zebra_printers[0]
                    return 'zebra'
            except ImportError:
                pass
        
        # Verificar puertos seriales para Zebra
        available_ports = serial.tools.list_ports.comports()
        for port in available_ports:
            # Zebra típicamente usa puertos USB serial con descripciones específicas
            if 'zebra' in port.description.lower() or 'zd' in port.description.lower():
                logger.info(f"✓ Impresora Zebra detectada en puerto: {port.device}")
                return 'zebra'
        
        logger.warning("No se detectó ninguna impresora compatible")
        return None
    
    def connect_printer(self, printer_type: str = None, **kwargs) -> bool:
        """Conecta con la impresora especificada o detecta automáticamente"""
        # Si no se especifica tipo, intentar autodetección
        if not printer_type:
            printer_type = self.auto_detect_printer()
            if not printer_type:
                logger.error("No se pudo detectar ningún tipo de impresora")
                return False
        
        self.current_printer_type = printer_type.lower()
        
        if self.current_printer_type == 'tsc':
            return self.tsc_printer.connect_usb_printer()
        elif self.current_printer_type == 'zebra':
            # Para Zebra, podemos conectar por Windows o serial
            if os.name == 'nt' and 'printer_name' in kwargs:
                return self.zebra_printer.connect_windows_printer(kwargs.get('printer_name'))
            elif 'port' in kwargs:
                baudrate = kwargs.get('baudrate', 9600)
                return self.zebra_printer.connect_serial_printer(kwargs.get('port'), baudrate)
            else:
                # Intentar conexión Windows por defecto
                if os.name == 'nt':
                    return self.zebra_printer.connect_windows_printer()
                else:
                    logger.error("Para Zebra en sistemas no-Windows, se requiere especificar el puerto serial")
                    return False
        else:
            logger.error(f"Tipo de impresora no soportado: {printer_type}")
            return False
    
    def print_label(self, content: str, ancho_mm: int = 80, alto_mm: int = 50) -> bool:
        """Imprime etiqueta usando la impresora conectada"""
        if not self.current_printer_type:
            logger.error("No hay impresora conectada")
            return False
            
        if self.current_printer_type == 'tsc':
            return self.tsc_printer.print_label(content, ancho_mm, alto_mm)
        elif self.current_printer_type == 'zebra':
            return self.zebra_printer.print_label(content, ancho_mm, alto_mm)
        else:
            logger.error(f"Tipo de impresora no soportado: {self.current_printer_type}")
            return False
    
    def test_impresora(self, ancho_mm: int = 80, alto_mm: int = 50) -> bool:
        """Ejecuta test de impresora usando la impresora conectada"""
        if not self.current_printer_type:
            logger.error("No hay impresora conectada")
            return False
            
        if self.current_printer_type == 'tsc':
            return self.tsc_printer.test_impresora(ancho_mm, alto_mm)
        elif self.current_printer_type == 'zebra':
            return self.zebra_printer.test_impresora(ancho_mm, alto_mm)
        else:
            logger.error(f"Tipo de impresora no soportado: {self.current_printer_type}")
            return False
    
    def disconnect(self):
        """Desconecta de la impresora actual"""
        if self.current_printer_type == 'tsc':
            self.tsc_printer.disconnect()
        elif self.current_printer_type == 'zebra':
            self.zebra_printer.disconnect()
        self.current_printer_type = None

# Instancias globales
scale_manager = ScaleManager()
printer_manager = MultiPrinterManager()

# Middleware para logging de requests
@app.before_request
def log_request_info():
    logger.info(f"Incoming request: {request.method} {request.url}")
    if request.data:
        logger.debug(f"Request data: {request.data}")

# Endpoints REST
@app.route('/health', methods=['GET'])
def health_check():
    """Endpoint de salud del servidor"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'services': {
            'scale': scale_manager.is_running,
            'printer': printer_manager.current_printer_type is not None
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
    reading = scale_manager.read_weight()
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
    except queue.Empty:
        pass
    
    return jsonify({'status': 'success', 'readings': readings})

@app.route('/printer/connect', methods=['POST'])
def connect_printer():
    """Conecta a la impresora (autodetección o especificada)"""
    data = request.get_json() or {}
    printer_type = data.get('type')  # 'tsc', 'zebra', o None para autodetección
    printer_name = data.get('printer_name')  # Para impresoras Windows Zebra
    port = data.get('port')  # Para impresoras seriales
    baudrate = data.get('baudrate', 9600)
    
    kwargs = {}
    if printer_name:
        kwargs['printer_name'] = printer_name
    if port:
        kwargs['port'] = port
    if baudrate:
        kwargs['baudrate'] = baudrate
    
    if printer_manager.connect_printer(printer_type, **kwargs):
        return jsonify({
            'status': 'success', 
            'message': f'Impresora {printer_manager.current_printer_type.upper()} conectada',
            'type': printer_manager.current_printer_type
        })
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

@app.route('/printer/detect', methods=['GET'])
def detect_printer():
    """Detecta automáticamente el tipo de impresora conectada"""
    printer_type = printer_manager.auto_detect_printer()
    if printer_type:
        return jsonify({
            'status': 'success',
            'printer_type': printer_type,
            'message': f'Impresora {printer_type.upper()} detectada'
        })
    else:
        return jsonify({
            'status': 'error',
            'printer_type': None,
            'message': 'No se detectó ninguna impresora compatible'
        }), 404

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

# Servidor de desarrollo con auto-reload
if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Servidor Flask para comunicación serial.')
    parser.add_argument('--port', type=str, default='COM3', help='Puerto serial')
    parser.add_argument('--baudrate', type=int, default=115200, help='Baud rate')
    parser.add_argument('--parity', type=str, default='N', help='Paridad (N, E, O)')
    parser.add_argument('--stopbits', type=int, default=1, help='Bits de parada')
    parser.add_argument('--bytesize', type=int, default=8, help='Bits de datos')
    parser.add_argument('--host', type=str, default='0.0.0.0', help='Host para el servidor Flask')
    parser.add_argument('--flask-port', type=int, default=5000, help='Puerto para el servidor Flask')
    args = parser.parse_args()

    scale_manager.port = args.port
    scale_manager.baudrate = args.baudrate
    scale_manager.parity = args.parity
    scale_manager.stopbits = args.stopbits
    scale_manager.bytesize = args.bytesize

    logger.info("=== Servidor Flask para Comunicación Serial ===")
    logger.info("Compatible con TSC TX200, Zebra y báscula serial")
    logger.info("Versión multi-impresora - Compatible con https://wmsys.fly.dev/")
    logger.info("=" * 55)
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
    logger.info("")
    logger.info("IMPRESORA:")
    logger.info("  POST /printer/connect - Conectar impresora")
    logger.info("  POST /printer/detect - Detectar tipo de impresora")
    logger.info("  POST /printer/print - Imprimir etiqueta")
    logger.info("  POST /printer/test - Test de impresión")
    logger.info("  POST /printer/disconnect - Desconectar impresora")
    logger.info("=" * 55)
    logger.info(f"Servidor iniciado en http://{args.host}:{args.flask_port}")
    logger.info("Este servidor puede recibir solicitudes desde:")
    logger.info("  - https://wmsys.fly.dev")
    logger.info("  - http://localhost:3000")
    logger.info("  - http://127.0.0.1:3000")
    logger.info("=" * 55)
    
    app.run(host=args.host, port=args.flask_port, debug=False)