import serial
import serial.tools.list_ports
import time

PORT = "COM4"
BAUDRATES = [9600, 115200, 19200, 4800]

print(f"--- Diagnóstico de Puerto {PORT} ---")
ports = [p.device for p in serial.tools.list_ports.comports()]
print(f"Puertos detectados: {ports}")

if PORT not in ports:
    print(f"ERROR: {PORT} no está en la lista de puertos.")
else:
    for baud in BAUDRATES:
        print(f"\nIntentando {PORT} @ {baud}...")
        try:
            ser = serial.Serial(PORT, baud, timeout=1)
            print(f"SUCCESS: Puerto abierto en {baud}!")
            print("Cerrando...")
            ser.close()
            break
        except Exception as e:
            print(f"FAIL: {type(e).__name__} - {e}")
            
print("\n--- Fin de diagnóstico ---")
