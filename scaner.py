#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Controlador directo para impresora TSC TX200
Usa comunicación USB directa sin puerto serial
"""

import usb.core
import usb.util
import time

class TSCTX200:
    def __init__(self):
        self.device = None
        self.endpoint_out = None
        self.endpoint_in = None
        
    def conectar(self):
        """
        Conecta directamente con la impresora TSC TX200
        """
        print("Buscando impresora TSC TX200...")
        
        # Buscar dispositivo TSC TX200 (Vendor ID: 0x1203, Product ID: 0x0230)
        self.device = usb.core.find(idVendor=0x1203, idProduct=0x0230)
        
        if self.device is None:
            print("✗ Impresora TSC TX200 no encontrada")
            print("Verifica que esté conectada y encendida")
            return False
        
        print(f"✓ Impresora encontrada: {self.device}")
        
        try:
            # Configurar dispositivo
            if self.device.is_kernel_driver_active(0):
                print("Desconectando driver del kernel...")
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
                print("✗ No se encontró endpoint de salida")
                return False
            
            print(f"✓ Endpoint OUT: {self.endpoint_out.bEndpointAddress}")
            if self.endpoint_in:
                print(f"✓ Endpoint IN: {self.endpoint_in.bEndpointAddress}")
            
            return True
            
        except Exception as e:
            print(f"✗ Error al configurar dispositivo: {e}")
            return False
    
    def enviar_comando(self, comando):
        """
        Envía comando TSPL2 a la impresora
        """
        if not self.device or not self.endpoint_out:
            print("✗ Dispositivo no conectado")
            return False
        
        try:
            # Convertir comando a bytes si es necesario
            if isinstance(comando, str):
                comando = comando.encode('utf-8')
            
            # Enviar comando
            bytes_escritos = self.endpoint_out.write(comando)
            print(f"✓ Enviados {bytes_escritos} bytes")
            return True
            
        except Exception as e:
            print(f"✗ Error enviando comando: {e}")
            return False
    
    def leer_respuesta(self, timeout=1000):
        """
        Lee respuesta de la impresora
        """
        if not self.device or not self.endpoint_in:
            print("! No hay endpoint de entrada configurado")
            return None
        
        try:
            data = self.endpoint_in.read(64, timeout)
            return data.tobytes()
        except usb.core.USBTimeoutError:
            print("! Timeout leyendo respuesta")
            return None
        except Exception as e:
            print(f"✗ Error leyendo: {e}")
            return None
    
    def test_impresora(self, ancho_mm=None, alto_mm=None):
        """
        Realiza test básico de la impresora con tamaños configurables
        """
        print("\n=== TEST DE IMPRESORA ===")
        
        # Obtener tamaño del papel del usuario si no se proporciona
        if ancho_mm is None:
            try:
                ancho_mm = float(input("Ancho del papel en mm (ej: 80): ") or "80")
            except:
                ancho_mm = 80
        
        if alto_mm is None:
            try:
                alto_mm = float(input("Alto del papel en mm (ej: 50): ") or "50")
            except:
                alto_mm = 50
        
        print(f"Configurando para papel: {ancho_mm}mm x {alto_mm}mm")
        
        # Comandos TSPL2 optimizados para TSC TX200
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
            
            # Texto centrado y bien posicionado
            f"TEXT {int(ancho_mm*2)},{int(alto_mm*1.5)},\"4\",0,1,1,\"TSC TX200 TEST\"\n",
            f"TEXT {int(ancho_mm*2)},{int(alto_mm*2.5)},\"3\",0,1,1,\"Papel: {ancho_mm}x{alto_mm}mm\"\n",
            f"TEXT {int(ancho_mm*2)},{int(alto_mm*3.5)},\"2\",0,1,1,\"Configuracion OK!\"\n",
            
            # Línea de separación
            f"BAR {int(ancho_mm*1.5)},{int(alto_mm*4.5)},{int(ancho_mm*5)},2\n",
            
            # Información de fecha/hora
            f"TEXT {int(ancho_mm*2)},{int(alto_mm*5.5)},\"1\",0,1,1,\"{time.strftime('%Y-%m-%d %H:%M')}\"\n",
            
            "PRINT 1,1\n"                             # Imprimir 1 copia
        ]
        print("Enviando comandos de test...")
        for i, comando in enumerate(comandos_test, 1):
            print(f"{i:2d}. {comando.strip()}")
            if self.enviar_comando(comando):
                time.sleep(0.1)  # Pequeña pausa entre comandos
            else:
                print(f"   ✗ Error enviando comando {i}")
                break
        
        print(f"\n✓ Test completado para papel {ancho_mm}x{alto_mm}mm")
        print("La etiqueta debería salir completa y centrada.")
        
    def calibrar_sensor(self):
        """
        Calibra el sensor de papel para detectar correctamente las etiquetas
        """
        print("\n=== CALIBRACIÓN DEL SENSOR ===")
        print("Asegúrate de que hay papel cargado en la impresora")
        input("Presiona Enter para continuar...")
        
        comandos_calibracion = [
            "CLS\n",                    # Limpiar buffer
            "~!AUTODETECT\n",          # Auto-detectar tipo de papel
            "INITIALPRINTER\n",        # Inicializar impresora
        ]
        
        print("Ejecutando calibración...")
        for comando in comandos_calibracion:
            print(f"Enviando: {comando.strip()}")
            if self.enviar_comando(comando):
                time.sleep(1)  # Esperar más tiempo para calibración
            else:
                print("Error en calibración")
                return False
        
        print("✓ Calibración completada")
        return True
    
    def configurar_tamaño_papel(self, ancho_mm, alto_mm, gap_mm=2):
        """
        Configura el tamaño del papel específicamente
        """
        print(f"\n=== CONFIGURANDO PAPEL {ancho_mm}x{alto_mm}mm ===")
        
        comandos_config = [
            "CLS\n",                                    # Limpiar buffer
            f"SIZE {ancho_mm} mm, {alto_mm} mm\n",     # Tamaño exacto
            f"GAP {gap_mm} mm, 0 mm\n",                # Espacio entre etiquetas
            "DIRECTION 1,0\n",                         # Dirección de impresión
            "REFERENCE 0,0\n",                         # Punto de referencia
            "OFFSET 0 mm\n",                           # Sin desplazamiento
            "DENSITY 8\n",                             # Densidad de impresión media
            "SPEED 4\n",                               # Velocidad media
        ]
        
        for comando in comandos_config:
            if not self.enviar_comando(comando):
                return False
            time.sleep(0.1)
        
        print("✓ Configuración de papel aplicada")
        return True
    
    def obtener_estado(self):
        """
        Obtiene estado de la impresora
        """
        print("\n=== ESTADO DE LA IMPRESORA ===")
        
        # Comando para obtener estado
        if self.enviar_comando("~!T\n"):  # Comando de estado TSPL2
            respuesta = self.leer_respuesta()
            if respuesta:
                print(f"Estado: {respuesta}")
            else:
                print("No se recibió respuesta de estado")
    
    def desconectar(self):
        """
        Desconecta de la impresora
        """
        if self.device:
            try:
                usb.util.dispose_resources(self.device)
                print("✓ Desconectado de la impresora")
            except:
                pass

def instalar_dependencias():
    """
    Verifica e instala dependencias necesarias
    """
    try:
        import usb.core
        print("✓ pyusb ya está instalado")
        return True
    except ImportError:
        print("✗ pyusb no está instalado")
        print("Instálalo con: pip install pyusb")
        print("En macOS también necesitas: brew install libusb")
        return False

def main():
    """
    Función principal
    """
    print("CONTROLADOR DIRECTO TSC TX200")
    print("="*40)
    
    # Verificar dependencias
    if not instalar_dependencias():
        return
    
    # Crear instancia de la impresora
    impresora = TSCTX200()
    
    try:
        # Conectar
        if impresora.conectar():
            print("\n✓ Impresora conectada exitosamente!")
            
            # Menú de opciones
            while True:
                print("\n" + "="*40)
                print("OPCIONES DISPONIBLES:")
                print("1. Calibrar sensor de papel")
                print("2. Configurar tamaño de papel")
                print("3. Test de impresión básico")
                print("4. Test con tamaño personalizado")
                print("5. Obtener estado")
                print("6. Salir")
                print("="*40)
                
                try:
                    opcion = input("Elige una opción (1-6): ").strip()
                    
                    if opcion == "1":
                        impresora.calibrar_sensor()
                    
                    elif opcion == "2":
                        try:
                            ancho = float(input("Ancho en mm: "))
                            alto = float(input("Alto en mm: "))
                            gap = float(input("Separación entre etiquetas en mm (2): ") or "2")
                            impresora.configurar_tamaño_papel(ancho, alto, gap)
                        except ValueError:
                            print("Error: Introduce números válidos")
                    
                    elif opcion == "3":
                        impresora.test_impresora(80, 50)  # Tamaño estándar
                    
                    elif opcion == "4":
                        impresora.test_impresora()  # Preguntará el tamaño
                    
                    elif opcion == "5":
                        impresora.obtener_estado()
                    
                    elif opcion == "6":
                        break
                    
                    else:
                        print("Opción no válida")
                        
                except KeyboardInterrupt:
                    print("\nSaliendo...")
                    break
            
        else:
            print("\n✗ No se pudo conectar con la impresora")
            print("Verifica:")
            print("1. Que esté encendida")
            print("2. Que esté conectada via USB")
            print("3. Que tengas permisos (podría necesitar sudo)")
    
    except KeyboardInterrupt:
        print("\nOperación cancelada")
    
    finally:
        impresora.desconectar()

if __name__ == "__main__":
    main()