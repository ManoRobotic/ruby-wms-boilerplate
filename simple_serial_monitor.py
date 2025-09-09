#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script simple para leer y mostrar datos del puerto serial en consola
"""

import serial
import serial.tools.list_ports
import time
import sys
import argparse
from datetime import datetime

def list_serial_ports():
    """Lista los puertos seriales disponibles"""
    ports = serial.tools.list_ports.comports()
    print("Puertos seriales disponibles:")
    for port in ports:
        print(f"  {port.device} - {port.description}")
    return ports

def main():
    parser = argparse.ArgumentParser(description='Monitor simple de puerto serial')
    parser.add_argument('--port', type=str, default='/dev/ttyUSB0', help='Puerto serial (ej. /dev/ttyUSB0, COM3)')
    parser.add_argument('--baudrate', type=int, default=115200, help='Baud rate')
    parser.add_argument('--parity', type=str, default='N', help='Paridad (N, E, O)')
    parser.add_argument('--stopbits', type=int, default=1, help='Bits de parada')
    parser.add_argument('--bytesize', type=int, default=8, help='Bits de datos')
    parser.add_argument('--list-ports', action='store_true', help='Listar puertos disponibles')
    
    args = parser.parse_args()
    
    # Si se solicita listar puertos, hacerlo y salir
    if args.list_ports:
        list_serial_ports()
        return
    
    try:
        # Conectar al puerto serial
        ser = serial.Serial(
            port=args.port,
            baudrate=args.baudrate,
            parity=args.parity,
            stopbits=args.stopbits,
            bytesize=args.bytesize,
            timeout=1
        )
        
        print(f"Conectado al puerto {args.port} a {args.baudrate} baudios")
        print("Leyendo datos del puerto serial. Presiona Ctrl+C para salir.")
        print("-" * 50)
        
        # Leer datos continuamente
        while True:
            if ser.in_waiting > 0:
                # Leer línea del puerto serial
                data = ser.readline().decode('utf-8', errors='ignore').strip()
                if data:  # Solo mostrar si hay datos
                    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    # Mostrar con colores (si la terminal lo soporta)
                    print(f"\033[92m[{timestamp}]\033[0m \033[93m{data}\033[0m")
            
            # Pequeña pausa para no consumir demasiado CPU
            time.sleep(0.01)
            
    except serial.SerialException as e:
        print(f"Error de conexión serial: {e}")
        print("Verifica que el puerto esté disponible y correctamente configurado.")
        sys.exit(1)
        
    except KeyboardInterrupt:
        print("\nInterrupción del usuario. Cerrando conexión...")
        
    except Exception as e:
        print(f"Error inesperado: {e}")
        sys.exit(1)
        
    finally:
        # Cerrar conexión si está abierta
        if 'ser' in locals() and ser.is_open:
            ser.close()
            print("Puerto serial cerrado.")

if __name__ == "__main__":
    main()