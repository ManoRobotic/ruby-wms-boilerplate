#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Cliente de Action Cable para comunicación serial con báscula e impresora.
Versión para Windows con soporte para win32print.
Este script ya no es un servidor, sino un cliente persistente.
"""
import sys
import os
import argparse
import threading
import time
import json
import serial
import serial.tools.list_ports
from datetime import datetime
import logging
import queue
import uuid
from actioncable.connection import Connection
from actioncable.channel import Channel

# Importar win32print para impresión en Windows
try:
    import win32print
    WIN32_AVAILABLE = True
    print("✓ win32print disponible")
except ImportError:
    WIN32_AVAILABLE = False
    print("✗ win32print no disponible - instala con: pip install pywin32")

# --- Configuración de Logging ---
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# --- Clases de Gestión de Hardware (Sin cambios significativos en su lógica interna) ---

class ScaleReading:
    def __init__(self, weight, timestamp, status="success"):
        self.weight = weight
        self.timestamp = timestamp
        self.status = status

class ScaleManager:
    def __init__(self, port='COM3', baudrate=115200):
        self.port = port
        self.baudrate = baudrate
        self.serial_connection = None
        self.is_running = False
        self.connected = False
        self.read_thread = None
        self.stop_event = threading.Event()

    def connect(self) -> bool:
        try:
            if self.serial_connection and self.serial_connection.is_open:
                logger.info(f"Báscula ya conectada en {self.port}")
                return True
            
            self.serial_connection = serial.Serial(self.port, self.baudrate, timeout=1)
            self.connected = self.serial_connection.is_open
            if self.connected:
                logger.info(f"✅ Conexión de báscula establecida en el puerto {self.port}")
                return True
            else:
                logger.error(f"✗ No se pudo abrir el puerto {self.port}")
                return False
        except serial.SerialException as e:
            logger.error(f"✗ Error de conexión serial en báscula: {e}")
            return False

    def disconnect(self):
        self.stop_continuous_reading()
        if self.serial_connection and self.serial_connection.is_open:
            self.serial_connection.close()
            self.connected = False
            logger.info("Báscula desconectada.")

    def read_weight(self, timeout=2):
        if not self.connected:
            return None
        
        start_time = time.time()
        while time.time() - start_time < timeout:
            if self.serial_connection.in_waiting > 0:
                try:
                    data = self.serial_connection.readline().decode('utf-8').strip()
                    if data:
                        logger.info(f"Peso leído: {data}")
                        return ScaleReading(weight=data, timestamp=datetime.now().isoformat())
                except Exception as e:
                    logger.warning(f"Error decodificando datos de la báscula: {e}")
            time.sleep(0.1)
        return None

    def start_continuous_reading(self, callback):
        if self.is_running:
            logger.info("Lectura continua ya está en ejecución.")
            return

        self.is_running = True
        self.stop_event.clear()

        def read_loop():
            while not self.stop_event.is_set():
                if not self.connected:
                    logger.warning("Báscula no conectada. Intentando reconectar...")
                    self.connect()
                    time.sleep(5) # Esperar antes de reintentar
                    continue
                
                reading = self.read_weight()
                if reading:
                    callback(reading) # Llamar al callback con la nueva lectura
                time.sleep(0.5) # Pequeña pausa entre lecturas

        self.read_thread = threading.Thread(target=read_loop, daemon=True)
        self.read_thread.start()
        logger.info("Lectura continua de báscula iniciada.")

    def stop_continuous_reading(self):
        self.is_running = False
        if self.stop_event:
            self.stop_event.set()
        if self.read_thread:
            self.read_thread.join(timeout=2)


class PrinterManager:
    def __init__(self):
        self.printer_name = None
        self.is_connected = False
        self.connect_printer()

    def connect_printer(self) -> bool:
        if not WIN32_AVAILABLE:
            logger.info("✗ win32print no está disponible, no se puede gestionar la impresora.")
            return False
        
        try:
            printers = [p[2] for p in win32print.EnumPrinters(win32print.PRINTER_ENUM_LOCAL | win32print.PRINTER_ENUM_CONNECTIONS)]
            tsc_printers = [p for p in printers if 'TSC' in p.upper()] # Búsqueda más genérica para TSC
            
            if not tsc_printers:
                logger.warning("No se encontró una impresora TSC. La función de impresión no estará disponible.")
                self.is_connected = False
                return False

            self.printer_name = tsc_printers[0]
            self.is_connected = True
            logger.info(f"✅ Impresora TSC encontrada y lista: {self.printer_name}")
            return True
        except Exception as e:
            logger.error(f"✗ Error buscando impresora: {e}")
            self.is_connected = False
            return False

    def print_label(self, content: str, ancho_mm: int = 80, alto_mm: int = 50) -> bool:
        if not self.is_connected:
            logger.error("No hay impresora conectada para imprimir.")
            return False
        
        try:
            hPrinter = win32print.OpenPrinter(self.printer_name)
            try:
                full_content = content
                if "SIZE" not in content.upper():
                     full_content = f"SIZE {ancho_mm} mm, {alto_mm} mm\nCLS\n{content}\nPRINT 1\n"
                
                logger.info(f"Imprimiendo en {self.printer_name}:\n---INICIO CONTENIDO---\n{full_content}\n---FIN CONTENIDO---")

                hJob = win32print.StartDocPrinter(hPrinter, 1, ("Label", None, "RAW"))
                win32print.StartPagePrinter(hPrinter)
                win32print.WritePrinter(hJob, full_content.encode('utf-8')) # Fixed hPrinter to hJob
                win32print.EndPagePrinter(hPrinter)
                win32print.EndDocPrinter(hJob)
            finally:
                win32print.ClosePrinter(hPrinter)
            
            logger.info("✓ Etiqueta enviada a la impresora.")
            return True
        except Exception as e:
            logger.error(f"✗ Error al imprimir: {e}")
            return False

# --- Lógica del Cliente de Action Cable ---

class SerialChannel(Channel):
    def __init__(self, connection, identifier, **kwargs):
        super().__init__(connection, identifier)
        self.scale_manager = kwargs.get('scale_manager')
        self.printer_manager = kwargs.get('printer_manager')
        logger.info(f"Canal SerialChannel inicializado con ID: {identifier}")

    def on_receive(self, message):
        logger.info(f"Mensaje recibido: {message}")
        action = message.get('action')

        if action == 'print_label':
            content = message.get('content')
            ancho_mm = message.get('ancho_mm', 80)
            alto_mm = message.get('alto_mm', 50)
            if content:
                logger.info("Comando de impresión recibido.")
                success = self.printer_manager.print_label(content, ancho_mm, alto_mm)
                self.perform('receive', {
                    'action': 'print_status',
                    'original_message': message,
                    'status': 'success' if success else 'error'
                })
        elif action == 'request_status':
            logger.info("Solicitud de estado recibida.")
            self.send_status()

    def on_confirm_subscription(self):
        logger.info("✓ Suscrito exitosamente a SerialConnectionChannel.")
        if self.scale_manager:
            self.scale_manager.start_continuous_reading(self.send_weight_update)
        self.send_status()

    def on_reject_subscription(self):
        logger.error("✗ Suscripción al canal rechazada por el servidor.")

    def send_weight_update(self, reading: ScaleReading):
        if self.connection.is_connected():
            logger.info(f"Enviando actualización de peso: {reading.weight}")
            self.perform('receive', {
                'action': 'weight_update',
                'weight': reading.weight,
                'timestamp': reading.timestamp,
                'device_id': self.identifier.get('device_id')
            })

    def send_status(self):
        if self.connection.is_connected():
            status = {
                'action': 'status_update',
                'device_id': self.identifier.get('device_id'),
                'scale_connected': self.scale_manager.connected if self.scale_manager else False,
                'printer_connected': self.printer_manager.is_connected if self.printer_manager else False,
                'printer_name': self.printer_manager.printer_name if self.printer_manager else None,
                'timestamp': datetime.now().isoformat()
            }
            logger.info(f"Enviando estado del dispositivo: {status}")
            self.perform('receive', status)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Cliente serial para WMSys.')
    parser.add_argument('--url', type=str, default='wss://wmsys.fly.dev/cable', help='URL del servidor de Action Cable.')
    parser.add_argument('--device-id', type=str, help='ID único para este dispositivo. Si no se provee, se genera uno.')
    parser.add_argument('--scale-port', type=str, default='COM3', help='Puerto serial de la báscula.')
    args = parser.parse_args()

    device_id = args.device_id
    if not device_id:
        try:
            mac = ':'.join(['{:02x}'.format((uuid.getnode() >> i) & 0xff) for i in range(0, 8*6, 8)][::-1])
            device_id = f"device-serial-{mac}"
        except:
            device_id = f"device-serial-{uuid.uuid4()}"
    
    logger.info(f"Usando Device ID: {device_id}")

    scale_manager = ScaleManager(port=args.scale_port)
    printer_manager = PrinterManager()

    while True:
        try:
            logger.info(f"Intentando conectar a {args.url}...")
            connection = Connection(url=args.url)
            connection.connect()
            logger.info("Conexión WebSocket establecida. Suscribiendo al canal...")

            channel_identifier = {'channel': 'SerialConnectionChannel', 'device_id': device_id}
            serial_channel = connection.subscribe(
                SerialChannel, 
                identifier=channel_identifier,
                scale_manager=scale_manager, 
                printer_manager=printer_manager
            )

            while connection.is_connected():
                time.sleep(5)
                if serial_channel:
                    serial_channel.send_status()

            logger.warning("Se ha perdido la conexión. Reintentando en 10 segundos...")
            scale_manager.stop_continuous_reading()
            connection.disconnect()
            time.sleep(10)

        except KeyboardInterrupt:
            logger.info("Cerrando cliente por petición del usuario...")
            if 'connection' in locals() and connection.is_connected():
                scale_manager.stop_continuous_reading()
                connection.disconnect()
            break
        except Exception as e:
            logger.error(f"Error en el bucle principal: {e}. Reintentando en 15 segundos...")
            if 'connection' in locals():
                try:
                    connection.disconnect()
                except:
                    pass
            scale_manager.stop_continuous_reading()
            time.sleep(15)