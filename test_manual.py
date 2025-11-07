#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script para probar manualmente la impresión de una etiqueta de prueba
simulando la funcionalidad del botón Test TSC
"""

import usb.core
import usb.util
import time
import logging
from datetime import datetime

# Configurar logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def test_impresora_manual():
    """Función para probar manualmente la impresión de una etiqueta"""
    try:
        logger.info("Buscando impresora TSC TX200...")
        
        # Buscar dispositivo TSC TX200 (Vendor ID: 0x1203, Product ID: 0x0230)
        device = usb.core.find(idVendor=0x1203, idProduct=0x0230)

        if device is None:
            logger.error("✗ Impresora TSC TX200 no encontrada")
            logger.error("Verifica que esté conectada y encendida")
            return False

        logger.info(f"✓ Impresora encontrada: {device}")

        try:
            # Configurar dispositivo
            if device.is_kernel_driver_active(0):
                logger.info("Desconectando driver del kernel...")
                device.detach_kernel_driver(0)
        except usb.core.USBError as e:
            if e.errno == 13:  # Permission denied
                logger.error("✗ Error de permisos al intentar acceder al dispositivo USB")
                logger.error("   Necesitas ejecutar este script como administrador o con permisos adecuados")
                return False
            else:
                logger.error(f"✗ Error al manipular driver del kernel: {str(e)}")
                return False

        # Establecer configuración
        try:
            device.set_configuration()
        except usb.core.USBError as e:
            if e.errno == 13:  # Permission denied
                logger.error("✗ Error de permisos al intentar configurar el dispositivo USB")
                logger.error("   Necesitas ejecutar este script como administrador o con permisos adecuados")
                return False
            else:
                logger.error(f"✗ Error al configurar el dispositivo: {str(e)}")
                return False

        # Obtener interface y endpoints
        cfg = device.get_active_configuration()
        intf = cfg[(0,0)]

        # Encontrar endpoints
        endpoint_out = usb.util.find_descriptor(
            intf,
            custom_match = lambda e: \
                usb.util.endpoint_direction(e.bEndpointAddress) == \
                usb.util.ENDPOINT_OUT
        )

        endpoint_in = usb.util.find_descriptor(
            intf,
            custom_match = lambda e: \
                usb.util.endpoint_direction(e.bEndpointAddress) == \
                usb.util.ENDPOINT_IN
        )

        if endpoint_out is None:
            logger.error("✗ No se encontró endpoint de salida")
            return False

        logger.info(f"✓ Endpoint OUT: {endpoint_out.bEndpointAddress}")
        if endpoint_in:
            logger.info(f"✓ Endpoint IN: {endpoint_in.bEndpointAddress}")

        logger.info("✓ Impresora conectada exitosamente!")
        
        # Parámetros de la etiqueta
        ancho_mm = 80
        alto_mm = 50
        
        logger.info("=== IMPRESIÓN DE PRUEBA MANUAL ===")
        logger.info(f"Configurando para papel: {ancho_mm}mm x {alto_mm}mm")
        
        # Comandos de test como en scaner.py
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
        
        logger.info("Enviando comandos de impresión de prueba...")
        for i, comando in enumerate(comandos_test, 1):
            logger.info(f"{i:2d}. {comando.strip()}")
            
            try:
                # Convertir comando a bytes
                if isinstance(comando, str):
                    comando = comando.encode('utf-8')
                
                # Enviar comando
                bytes_escritos = endpoint_out.write(comando)
                logger.debug(f"✓ Enviados {bytes_escritos} bytes: {comando.decode('utf-8').strip()}")
                
                time.sleep(0.1)  # Pequeña pausa entre comandos
            except usb.core.USBError as e:
                if e.errno == 13:  # Permission denied
                    logger.error("✗ Error de permisos al intentar enviar comando al dispositivo USB")
                    logger.error("   Necesitas ejecutar este script como administrador o con permisos adecuados")
                    return False
                else:
                    logger.error(f"✗ Error de USB al enviar comando: {str(e)}")
                    return False
            except Exception as e:
                logger.error(f"✗ Error enviando comando {i}: {str(e)}")
                return False
        
        logger.info(f"✓ Prueba completada para papel {ancho_mm}x{alto_mm}mm")
        logger.info("La etiqueta de prueba debería salir completa y centrada.")
        return True
        
    except usb.core.USBError as e:
        if e.errno == 13:  # Permission denied
            logger.error("✗ Error de permisos durante la impresión de prueba")
            logger.error("   Necesitas ejecutar este script como administrador o con permisos adecuados")
            return False
        else:
            logger.error(f"✗ Error de USB durante la impresión de prueba: {str(e)}")
            return False
    except Exception as e:
        logger.error(f"✗ Error durante la impresión de prueba: {str(e)}")
        return False

if __name__ == "__main__":
    print("Iniciando prueba manual de impresión TSC TX200...")
    print("Asegúrate de tener permisos adecuados para acceder al dispositivo USB")
    print()
    
    success = test_impresora_manual()
    
    if success:
        print()
        print("✓ Prueba de impresión completada exitosamente")
        print("✓ La etiqueta de prueba debería haber salido de la impresora")
    else:
        print()
        print("✗ La prueba de impresión falló")
        print("✗ Verifica que la impresora esté conectada y que tengas permisos suficientes")