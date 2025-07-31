# Manual de Configuración - Impresora TSC TX200

## Descripción
Este documento describe cómo configurar y usar la funcionalidad de impresión manual para la impresora TSC TX200 integrada en el sistema WMS.

## Requisitos del Sistema

### Hardware
- Impresora TSC TX200 conectada via USB
- Cable USB A-B
- Etiquetas compatibles (recomendado: 80x50mm)

### Software
- Python 3.x
- Biblioteca pyusb
- Permisos USB adecuados

## Instalación

### 1. Dependencias del Sistema
```bash
# Ejecutar el script de instalación incluido
./bin/install_printer_deps

# O manualmente:
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-usb libusb-1.0-0-dev
```

### 2. Configuración de Permisos USB
```bash
# Crear regla udev para TSC TX200
sudo bash -c 'cat > /etc/udev/rules.d/99-tsc-printer.rules << EOF
SUBSYSTEM=="usb", ATTR{idVendor}=="1203", ATTR{idProduct}=="0230", MODE="0666", GROUP="plugdev"
EOF'

# Recargar reglas
sudo udevadm control --reload-rules
sudo udevadm trigger

# Agregar usuario al grupo plugdev
sudo usermod -a -G plugdev $USER
```

### 3. Verificar Instalación
```bash
python3 -c "import usb.core; print('pyusb OK')"
lsusb | grep -i tsc  # Debería mostrar la impresora si está conectada
```

## Uso del Sistema

### Acceso a la Interfaz
1. Iniciar sesión como administrador
2. Navegar a **Admin Panel**
3. Hacer clic en **"Impresión Manual"** en el sidebar

### Flujo de Trabajo

#### 1. Conectar Impresora
- Asegurarse de que la impresora esté encendida y conectada via USB
- Hacer clic en **"Conectar Impresora"**
- El sistema intentará detectar la TSC TX200 automáticamente
- El indicador de estado cambiará a verde si la conexión es exitosa

#### 2. Configurar Papel (Opcional)
- Ajustar dimensiones del papel:
  - **Ancho**: Ancho de la etiqueta en milímetros (ej: 80mm)
  - **Alto**: Alto de la etiqueta en milímetros (ej: 50mm)
  - **Separación**: Espacio entre etiquetas en milímetros (ej: 2mm)

#### 3. Calibrar Sensor (Recomendado)
- Hacer clic en **"Calibrar Sensor"**
- Esto permite que la impresora detecte correctamente las etiquetas
- Ejecutar después de cambiar el tipo de papel

#### 4. Imprimir Etiqueta de Test
- Configurar las dimensiones deseadas
- Hacer clic en **"Imprimir Etiqueta de Test"**
- La etiqueta incluirá:
  - Texto de identificación "TSC TX200 TEST"
  - Dimensiones configuradas
  - Fecha y hora actual
  - Línea de separación para verificar posicionamiento

#### 5. Verificar Estado
- Hacer clic en **"Estado de Impresora"** para obtener información del dispositivo

## Especificaciones de la Impresora TSC TX200

### Identificación USB
- **Vendor ID**: 0x1203
- **Product ID**: 0x0230

### Tamaños de Papel Compatibles
- **Ancho**: 20-118mm
- **Alto**: 10-2000mm
- **Tipos**: Etiquetas térmicas directas o transferencia térmica

### Configuraciones Recomendadas
- **Papel estándar**: 80mm x 50mm
- **Separación**: 2mm
- **Densidad**: 8 (media)
- **Velocidad**: 4 (media)

## Comandos TSPL2 Utilizados

El sistema utiliza el lenguaje de comandos TSPL2 nativo de TSC:

```tspl
SIZE 80 mm, 50 mm          # Tamaño del papel
GAP 2 mm, 0 mm             # Separación entre etiquetas
DIRECTION 1,0              # Dirección normal
CLS                        # Limpiar buffer
TEXT 160,75,"4",0,1,1,"TEST"  # Texto de prueba
PRINT 1,1                  # Imprimir 1 copia
```

## Solución de Problemas

### Error: "Impresora no encontrada"
1. Verificar que la impresora esté encendida
2. Verificar conexión USB
3. Ejecutar: `lsusb | grep -i tsc`
4. Revisar permisos: `ls -la /dev/bus/usb/`

### Error: "Permisos insuficientes"
1. Ejecutar Rails como administrador: `sudo bin/dev`
2. O configurar permisos USB como se describió arriba
3. Reiniciar sesión después de agregar usuario al grupo plugdev

### Error: "Comando no enviado"
1. Revisar que la impresora esté lista (no en error)
2. Verificar que el papel esté correctamente cargado
3. Intentar calibrar el sensor

### La etiqueta se imprime mal posicionada
1. Calibrar el sensor de papel
2. Verificar que las dimensiones configuradas coincidan con el papel real
3. Ajustar la separación entre etiquetas

### Error de Python/pyusb
1. Verificar instalación: `python3 -c "import usb.core"`
2. Reinstalar dependencias: `sudo apt-get install --reinstall python3-usb`

## Logs y Depuración

### Registro de Actividad
- La interfaz web muestra un log en tiempo real de todas las operaciones
- Los mensajes incluyen timestamps y códigos de color por tipo:
  - **Azul**: Información general
  - **Verde**: Operaciones exitosas
  - **Amarillo**: Advertencias
  - **Rojo**: Errores

### Logs del Sistema
Los logs detallados se pueden encontrar en:
- Rails logs: `log/development.log`
- Sistema: `/var/log/syslog` (para problemas USB)

## Contacto y Soporte

Para problemas técnicos:
1. Revisar el log de actividad en la interfaz web
2. Verificar los logs de Rails
3. Ejecutar diagnósticos USB: `lsusb -v -d 1203:0230`

## Notas Importantes

- ⚠️ **Seguridad**: El sistema ejecuta scripts Python con permisos de sistema
- ⚠️ **Compatibilidad**: Diseñado específicamente para TSC TX200
- ⚠️ **Rendimiento**: Las operaciones de impresión tienen timeout de 30 segundos
- ⚠️ **Concurrencia**: Solo una operación de impresión a la vez