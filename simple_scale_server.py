#!/usr/bin/env python3
"""
Servidor HTTP simple para pruebas
Simula las respuestas del servidor Flask de báscula
"""

import http.server
import json
import random
from datetime import datetime
import time
from urllib.parse import urlparse, parse_qs
import threading

# Variable para simular el estado de conexión
scale_connected = False
# Variable para controlar la lectura automática
auto_reading = False
# Lista para almacenar las lecturas
readings_queue = []

class ScaleTestHandler(http.server.BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        """Manejar solicitudes OPTIONS (preflight CORS)"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
    
    def do_GET(self):
        """Manejar solicitudes GET"""
        if self.path == '/health':
            self.handle_health()
        elif self.path == '/ports':
            self.handle_ports()
        elif self.path == '/scale/read':
            self.handle_scale_read()
        elif self.path == '/scale/last':
            self.handle_scale_last()
        elif self.path == '/scale/latest':
            self.handle_scale_latest()
        else:
            self.send_error(404, "Endpoint no encontrado")
    
    def do_POST(self):
        """Manejar solicitudes POST"""
        if self.path == '/scale/connect':
            self.handle_scale_connect()
        elif self.path == '/scale/disconnect':
            self.handle_scale_disconnect()
        elif self.path == '/scale/start':
            self.handle_scale_start()
        elif self.path == '/scale/stop':
            self.handle_scale_stop()
        else:
            self.send_error(404, "Endpoint no encontrado")
    
    def handle_health(self):
        """Manejar /health"""
        response = {
            'status': 'healthy',
            'timestamp': datetime.now().isoformat(),
            'services': {
                'scale': scale_connected
            }
        }
        self.send_json_response(response)
    
    def handle_ports(self):
        """Manejar /ports"""
        response = {
            'status': 'success',
            'ports': [
                {
                    'device': '/dev/ttyUSB0',
                    'description': 'Báscula Serial USB',
                    'hwid': 'USB VID:PID=1234:5678'
                },
                {
                    'device': '/dev/ttyUSB1',
                    'description': 'Impresora TSC TX200',
                    'hwid': 'USB VID:PID=1203:0230'
                },
                {
                    'device': 'COM3',
                    'description': 'Báscula Serial (Windows)',
                    'hwid': 'PNP0501'
                }
            ]
        }
        self.send_json_response(response)
    
    def handle_scale_connect(self):
        """Manejar /scale/connect"""
        global scale_connected
        scale_connected = True
        response = {
            'status': 'success',
            'message': 'Báscula conectada (simulada)'
        }
        self.send_json_response(response)
    
    def handle_scale_disconnect(self):
        """Manejar /scale/disconnect"""
        global scale_connected, auto_reading
        scale_connected = False
        auto_reading = False
        response = {
            'status': 'success',
            'message': 'Báscula desconectada (simulada)'
        }
        self.send_json_response(response)
    
    def handle_scale_start(self):
        time.sleep(15)

        """Manejar /scale/start"""
        global auto_reading
        if not scale_connected:
            self.send_error(400, json.dumps({
                'status': 'error',
                'message': 'Báscula no conectada'
            }))
            return
        
        auto_reading = True
        # Iniciar el hilo de lectura automática
        threading.Thread(target=self.auto_read_weight, daemon=True).start()
        
        response = {
            'status': 'success',
            'message': 'Lectura continua iniciada (simulada)'
        }
        self.send_json_response(response)
    
    def handle_scale_stop(self):
        """Manejar /scale/stop"""
        global auto_reading
        auto_reading = False
        response = {
            'status': 'success',
            'message': 'Lectura continua detenida (simulada)'
        }
        self.send_json_response(response)
    
    def auto_read_weight(self):

        time.sleep(15)

        """Generar lecturas automáticas cada 15 segundos"""
        global auto_reading, readings_queue
        while auto_reading and scale_connected:
            # Generar un peso aleatorio entre 1.0 y 150.0 kg
            weight = round(random.uniform(1.0, 150.0), 3)
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            # Agregar la lectura a la cola
            readings_queue.append({
                'weight': f"{weight:.3f}",
                'timestamp': timestamp,
                'status': 'success'
            })
            
            # Mantener solo las últimas 10 lecturas
            if len(readings_queue) > 10:
                readings_queue.pop(0)
            
            # Esperar 15 segundos
    
    def handle_scale_read(self):
        """Manejar /scale/read"""
        if not scale_connected:
            self.send_error(400, json.dumps({
                'status': 'error',
                'message': 'Báscula no conectada'
            }))
            return


        
        # Generar un peso aleatorio entre 1.0 y 150.0 kg
        weight = round(random.uniform(1.0, 150.0), 3)
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        response = {
            'status': 'success',
            'weight': f"{weight:.3f}",
            'timestamp': timestamp
        }
        self.send_json_response(response)
    
    def handle_scale_last(self):
        """Manejar /scale/last"""
        if not scale_connected:
            self.send_error(400, json.dumps({
                'status': 'error',
                'message': 'Báscula no conectada'
            }))
            return
        
        # Generar un peso aleatorio entre 1.0 y 150.0 kg
        weight = round(random.uniform(1.0, 150.0), 3)
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        
        response = {
            'status': 'success',
            'weight': f"{weight:.3f}",
            'timestamp': timestamp
        }
        self.send_json_response(response)
    
    def handle_scale_latest(self):
        """Manejar /scale/latest"""
        if not scale_connected:
            self.send_error(400, json.dumps({
                'status': 'error',
                'message': 'Báscula no conectada'
            }))
            return
        
        # Devolver las lecturas de la cola
        response = {
            'status': 'success',
            'readings': readings_queue.copy()
        }
        self.send_json_response(response)
    
    def send_json_response(self, data):
        """Enviar respuesta JSON"""
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode('utf-8'))

def run_server():
    """Iniciar el servidor"""
    server_address = ('localhost', 5002)
    httpd = http.server.HTTPServer(server_address, ScaleTestHandler)
    print("=== Servidor de prueba para báscula serial ===")
    print("Simula una báscula conectada por puerto serial")
    print("=" * 50)
    print("Endpoints disponibles:")
    print("  GET  /health - Estado del servidor")
    print("  GET  /ports - Puertos seriales disponibles")
    print("")
    print("BÁSCULA:")
    print("  POST /scale/connect - Conectar báscula")
    print("  POST /scale/start - Iniciar lectura continua (cada 15 segundos)")
    print("  POST /scale/stop - Detener lectura")
    print("  GET  /scale/read - Leer peso actual")
    print("  GET  /scale/last - Última lectura")
    print("  GET  /scale/latest - Lecturas de la cola")
    print("=" * 50)
    print("Servidor iniciado en http://localhost:5002")
    print("Presiona Ctrl+C para detener")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServidor detenido")
        httpd.server_close()

if __name__ == '__main__':
    run_server()