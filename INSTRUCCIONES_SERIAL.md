# 🚀 Cómo usar el Sistema Serial

## Paso 1: Iniciar el servidor Flask

```bash
# En una terminal separada
./start_serial_server.sh
```

El servidor debería iniciar en http://localhost:5000

## Paso 2: Iniciar la aplicación Rails

```bash
# En el devcontainer
bin/dev
```

## Paso 3: Probar la conexión

1. Ve a http://localhost:3000/admin/manual_printing
2. Deberías ver el panel de "Comunicación Serial" en la izquierda
3. El estado debería mostrar "✓ Serial server connected"

## Paso 4: Conectar dispositivos

### Báscula:
1. Selecciona el puerto COM (ej: COM3)
2. Click "Conectar"
3. Click "Leer ahora" para probar

### Impresora:
1. Click "Conectar" en la sección de impresora
2. Verifica que muestre "✓ Printer connected"

## Paso 5: Usar el sistema

1. **Capturar peso**: Click "Leer ahora" o activa lectura continua
2. **Configurar etiqueta**: Llena los campos del formulario
3. **Imprimir**: Click "Imprimir Etiqueta" (requiere peso > 0)

## 🔧 Solución de problemas

### Servidor Flask no inicia:
```bash
pip3 install -r requirements.txt
python3 serial_server.py
```

### Puerto ocupado:
```bash
sudo lsof -i :5000
sudo kill -9 <PID>
```

### Dispositivos no detectados:
- Verifica conexiones USB/Serial
- En Linux: `ls -l /dev/ttyUSB*`
- Permisos: `sudo usermod -a -G dialout $USER`

### Rails no conecta:
- Verifica que SERIAL_SERVER_URL=http://localhost:5000
- Revisa logs en log/development.log

## 📋 Endpoints útiles para testing

- http://localhost:5000/health - Estado del servidor
- http://localhost:5000/ports - Puertos disponibles
- http://localhost:3000/api/serial/health - Estado desde Rails

## 🎯 Flujo completo

1. ✅ Servidor Flask corriendo
2. ✅ Rails app corriendo  
3. ✅ Dispositivos conectados
4. ✅ Leer peso → ✅ Configurar etiqueta → ✅ Imprimir

¡El sistema está listo para usar! 🎉