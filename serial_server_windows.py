#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Cliente asíncrono de Action Cable para comunicación serial con báscula e impresora.
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
import aioactioncable

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
                self.serial_connection = serial.Serial(self.port, self.baudrate, timeout=1)
                self.connected = self.serial_connection.is_open
                if self.connected:
                    logger.info(f"✅ Conexión de báscula establecida en {self.port}")
                return self.connected
            except serial.SerialException as e:
                logger.error(f"✗ Error de conexión serial en báscula: {e}")
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

async def listen_for_commands(subscription, scale_manager, printer_manager):
    logger.info("Listener de comandos iniciado.")
    try:
        async for message in subscription:
            logger.info(f"Mensaje recibido: {message}")
            action = message.get('action')
            if action == 'set_config':
                logger.info("Comando de configuración recibido.")
                if message.get('scale_port'):
                    scale_manager.set_port(message['scale_port'])
                if message.get('printer_port'):
                    printer_manager.set_printer(message['printer_port'])
                save_config({
                    'scale_port': scale_manager.port,
                    'printer_port': printer_manager.printer_name
                })
    except Exception as e:
        logger.error(f"Error en el listener de comandos: {e}")

async def stream_updates(subscription, scale_manager, printer_manager, device_id):
    logger.info("Stream de actualizaciones iniciado.")
    while True:
        try:
            ports = await asyncio.to_thread(serial.tools.list_ports.comports)
            port_list = [{'device': p.device, 'description': p.description} for p in ports]
            if WIN32_AVAILABLE:
                printers = await asyncio.to_thread(win32print.EnumPrinters, win32print.PRINTER_ENUM_LOCAL | win32print.PRINTER_ENUM_CONNECTIONS)
                for p in printers:
                    port_list.append({'device': p[2], 'description': p[2]})

            await subscription.send({
                'action': 'receive',
                'data': {
                    'action': 'ports_update',
                    'ports': port_list,
                    'scale_port': scale_manager.port,
                    'scale_connected': scale_manager.connected,
                    'printer_port': printer_manager.printer_name,
                    'printer_connected': printer_manager.is_connected
                }
            })
            
            reading = await asyncio.to_thread(scale_manager.read_weight)
            if reading:
                await subscription.send({
                    'action': 'receive',
                    'data': {'action': 'weight_update', 'weight': reading['weight'], 'timestamp': reading['timestamp']}
                })
            
            await asyncio.sleep(5) 
        except Exception as e:
            logger.error(f"Error en el stream de actualizaciones: {e}")
            await asyncio.sleep(5)

async def main_loop(url, token, device_id, args):
    local_config = load_config()
    initial_scale_port = args.scale_port or local_config.get('scale_port') or 'COM3'
    initial_printer_port = args.printer_port or local_config.get('printer_port')

    scale_manager = ScaleManager(port=initial_scale_port)
    printer_manager = PrinterManager(printer_name=initial_printer_port)
    
    connection_url = f"{url}?token={token}"
    
    while True:
        try:
            logger.info(f"Intentando conectar a {url}...")
            async with aioactioncable.connect(connection_url) as connection:
                channel_identifier = {'channel': 'SerialConnectionChannel', 'device_id': device_id}
                subscription = await connection.subscribe(channel_identifier)
                logger.info(f"✓ Conexión y suscripción establecidas.")

                listener_task = asyncio.create_task(listen_for_commands(subscription, scale_manager, printer_manager))
                streamer_task = asyncio.create_task(stream_updates(subscription, scale_manager, printer_manager, device_id))
                
                done, pending = await asyncio.wait([listener_task, streamer_task], return_when=asyncio.FIRST_COMPLETED)
                for task in pending: task.cancel()
                logger.warning("Una de las tareas principales ha terminado, reconectando...")
        except Exception as e:
            logger.error(f"Error en el bucle de conexión: {type(e).__name__} - {e}")
        logger.warning("Conexión perdida. Reintentando en 15 segundos...")
        await asyncio.sleep(15)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Cliente serial para WMSys.')
    parser.add_argument('--url', type=str, default='ws://localhost:3000/cable', help='URL del servidor.')
    parser.add_argument('--token', type=str, required=True, help='Token de autenticación.')
    parser.add_argument('--device-id', type=str, help='ID único del dispositivo.')
    parser.add_argument('--scale-port', type=str, default=None, help='Puerto de la báscula.')
    parser.add_argument('--printer-port', type=str, default=None, help='Nombre de la impresora.')
    args = parser.parse_args()

    device_id = args.device_id or f"device-serial-{uuid.getnode()}"
    
    try:
        asyncio.run(main_loop(args.url, args.token, device_id, args))
    except KeyboardInterrupt:
        logger.info("Cliente cerrado.")