# Servidor Serial Flask - Integración WMS

Sistema de comunicación serial para báscula e impresora integrado con la aplicación Rails WMS.

## Características

- **Servidor Flask**: API REST para comunicación serial
- **Báscula**: Lectura de peso por puerto serial con polling continuo
- **Impresora TSC TX200**: Impresión de etiquetas via USB
- **Integración Rails**: Service y controllers para conectar con la app principal
- **Frontend**: Stimulus controller para manejo en tiempo real
- **Docker**: Configuración para despliegue con privilegios USB

## Arquitectura

```
Rails App (Puerto 3000) ↔ Flask Server (Puerto 5000) ↔ Dispositivos Serial/USB
                      HTTP/JSON                    Serial/USB
```

## Instalación y Uso

### Opción 1: Standalone (Desarrollo)

```bash
# Instalar dependencias
pip3 install -r requirements.txt

# Iniciar servidor
./start_serial_server.sh
```

### Opción 2: Docker (Producción)

```bash
# Construir y ejecutar
docker-compose -f docker-compose.serial.yml up --build

# Solo el servicio serial
docker-compose -f docker-compose.serial.yml up serial-server
```

## Endpoints API

### Estado
- `GET /health` - Estado del servidor
- `GET /ports` - Lista puertos seriales disponibles

### Báscula
- `POST /scale/connect` - Conectar báscula
- `POST /scale/start` - Iniciar lectura continua
- `POST /scale/stop` - Detener lectura
- `GET /scale/read` - Leer peso actual
- `GET /scale/last` - Última lectura
- `GET /scale/latest` - Lecturas más recientes
- `GET /scale/get_weight_now` - Obtener peso con timeout

### Impresora
- `POST /printer/connect` - Conectar impresora USB
- `POST /printer/print` - Imprimir etiqueta

## Integración con Rails

### Service

```ruby
# Conectar báscula
SerialCommunicationService.connect_scale(port: 'COM3')

# Leer peso
weight = SerialCommunicationService.read_scale_weight
# => { weight: "1.23 kg", timestamp: "2024-01-01 10:00:00" }

# Imprimir etiqueta
SerialCommunicationService.print_label("Código: ABC123")
```

### API Endpoints Rails

```
GET  /api/serial/health
POST /api/serial/connect_scale
GET  /api/serial/read_weight
POST /api/serial/print_label
```

### Frontend (Stimulus)

```erb
<%= render 'admin/serial/panel' %>
```

```javascript
// Leer peso desde otro controller
const serialController = this.application.getControllerForElementAndIdentifier(
  document.querySelector('[data-controller*="serial"]'), 'serial'
)
const weight = await serialController.getCurrentWeight()
```

## Configuración de Dispositivos

### Báscula
- Puerto: COM3 (Windows) / /dev/ttyUSB0 (Linux)
- Baudrate: 115200
- Protocolo: TSPL-EZ

### Impresora TSC TX200
- Conexión: USB
- Vendor ID: 0x1203
- Product ID: 0x0230
- Protocolo: TSPL

## Variables de Entorno

```bash
SERIAL_SERVER_URL=http://localhost:5000  # URL del servidor Flask
FLASK_ENV=development                    # Modo Flask
PYTHONUNBUFFERED=1                      # Logging sin buffer
```

## Archivos Principales

- `serial_server.py` - Servidor Flask principal
- `scaner.py` - Script original de báscula (referencia)
- `requirements.txt` - Dependencias Python
- `app/services/serial_communication_service.rb` - Service Rails
- `app/controllers/api/serial_controller.rb` - API Controller
- `app/javascript/controllers/serial_controller.js` - Frontend Stimulus
- `app/views/admin/serial/_panel.html.erb` - Panel de control
- `docker-compose.serial.yml` - Configuración Docker
- `start_serial_server.sh` - Script de inicio

## Solución de Problemas

### Permisos USB/Serial
```bash
# Agregar usuario a grupos
sudo usermod -a -G dialout $USER
sudo usermod -a -G plugdev $USER

# Reiniciar sesión
```

### Docker y dispositivos USB
```bash
# Verificar dispositivos
lsusb
ls -l /dev/ttyUSB*

# Ejecutar con privilegios
docker run --privileged --device /dev/ttyUSB0
```

### Puerto ocupado
```bash
# Verificar proceso usando puerto 5000
sudo lsof -i :5000
sudo kill -9 <PID>
```

## Logs y Debugging

- Logs Flask: Salida estándar
- Logs Rails: `log/development.log`
- Logs Docker: `docker-compose logs serial-server`

## Desarrollo

Para agregar nuevos dispositivos o funcionalidades:

1. Modificar `serial_server.py` - Agregar manager del dispositivo
2. Actualizar `SerialCommunicationService` - Agregar métodos Ruby
3. Extender `Api::SerialController` - Agregar endpoints
4. Actualizar `serial_controller.js` - Agregar funciones frontend