import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// Crear el consumer con la URL específica del cable
const consumer = createConsumer("/cable")

export default class extends Controller {
  static targets = ["status", "weight", "logs", "printerStatus", "scaleStatus", "scalePort", "printerPort"]

  connect() {
    this.deviceIdValue = this.element.dataset.serialDeviceIdValue
    this.log("Inicializando controlador Serial (v3)...")
    if (!this.deviceIdValue) {
      this.updateStatus("✗ Error: No se proporcionó un ID de dispositivo.", "error")
      return
    }

    // Initialize state
    this.availablePorts = [];
    this.configuredScalePort = null;
    this.configuredPrinterPort = null;
    this.lastScaleState = false;
    this.lastPrinterState = false;
    this.pendingScaleAutoSave = false;
    this.pendingPrinterAutoSave = false;

    // Initialize dropdowns with placeholder text while waiting for data
    if (this.hasScalePortTarget) {
      this.scalePortTarget.innerHTML = '<option value="">Cargando puertos...</option>';
    }
    if (this.hasPrinterPortTarget) {
      this.printerPortTarget.innerHTML = '<option value="">Cargando impresoras...</option>';
    }

    this.initActionCable()
  }

  disconnect() {
    if (this.channel) {
      consumer.subscriptions.remove(this.channel)
    }
  }

  initActionCable() {
    // Antes de crear una nueva suscripción, asegurémonos de eliminar la anterior si existe
    if (this.channel) {
      consumer.subscriptions.remove(this.channel);
    }

    this.channel = consumer.subscriptions.create(
      { channel: "SerialConnectionChannel", device_id: this.deviceIdValue },
      {
        connected: () => {
          this.log("✓ Conectado a SerialConnectionChannel.")
          this.updateStatus("✓ Conectado", "success")

          // Request current configuration after connection is established
          setTimeout(() => {
            this.requestCurrentConfig();
          }, 1000); // Wait a bit for the connection to be fully established
        },
        disconnected: () => {
          this.log("↻ Desconectado del canal.")
          this.updateStatus("↻ Desconectado", "warning")
          // Intentar reconexión automática después de un breve periodo
          setTimeout(() => {
            if (document.visibilityState === 'visible') {
              // Intentar reconectar sin recargar la página
              this.initActionCable();
            }
          }, 5000); // Reconectar después de 5 segundos
        },
        received: (data) => {
          this.log(`ActionCable RAW: ${JSON.stringify(data)}`)
          if (data && typeof data === 'object') {
            this.log(`ActionCable Action: ${data.action}`)
          }
          this.route_action(data)
        }
      }
    )
  }

  // Method to request current configuration and ports from the server
  requestCurrentConfig() {
    if (this.channel) {
      this.log("Solicitando configuración y lista de puertos actual...");
      this.channel.perform('request_ports', {});
    }
  }

  // --- Enrutador de Acciones ---
  route_action(data) {
    try {
      this.log(`Acción recibida: ${data.action}`);
      this.log(`Datos completos recibidos:`, JSON.stringify(data));

      // Debugging: Log all available properties in the data
      this.log(`Propiedades en el objeto data:`, Object.keys(data || {}));

      switch (data.action) {
        case 'weight_update':
          this.log(`Peso recibido: ${data.weight} en ${data.timestamp}`);
          this.updateWeight(data.weight, data.timestamp)
          // Despachar un evento global para que otros controllers puedan escucharlo
          this.dispatch("weightUpdate", {
            detail: { weight: data.weight, timestamp: data.timestamp },
            bubbles: true
          })
          break
        case 'status_update':
          this.handleStatusUpdate(data)
          break
        case 'ports_update':
          this.handlePortsUpdate(data)
          break
        case 'set_config':
          this.log(`Configuración recibida: ${JSON.stringify(data)}`)
          this.handleStatusUpdate(data)
          break
        case 'pong':
          this.log(`Respuesta de ping recibida: ${JSON.stringify(data)}`)
          break
        default:
          this.log(`ActionCable Unhandled: ${data.action || 'no-action'}`)
          this.log(`ActionCable Data:`, data)
      }
    } catch (error) {
      this.log(`Error procesando acción '${data.action}':`, error);
      console.error('Error in route_action:', error);
    }
  }

  clearLogs() {
    if (this.hasLogsTarget) {
      this.logsTarget.innerHTML = '';
      this.log("✓ Registros limpiados.");
    }
  }

  saveConfiguration(event) {
    this.log("saveConfiguration interceptado (click en botón guardar)");
    // The form will submit normally, but we can also trigger a manual config scan if we want
    // For now, let's just make sure we don't block the submit
  }

  // --- Acciones que envían datos al backend ---
  connectScale() {
    const port = this.scalePortTarget.value
    if (!port) {
      alert("Por favor, seleccione un puerto para la báscula.")
      return
    }
    this.log(`Conectando báscula en puerto: ${port}`)
    this.channel.perform('connect_scale', { port: port })
    
    // Actualizar el puerto "configurado" localmente para que la UI lo marque como seleccionado
    this.configuredScalePort = port
    
    // Marcar que queremos guardar automáticamente si se conecta con éxito
    this.pendingScaleAutoSave = true
  }

  disconnectScale() {
    this.log("Desconectando báscula...")
    this.channel.perform('disconnect_scale', {})
    this.pendingScaleAutoSave = false
  }

  connectPrinter() {
    const port = this.printerPortTarget.value
    if (!port) {
      alert("Por favor, seleccione un nombre de impresora.")
      return
    }
    this.log(`Conectando impresora: ${port}`)
    this.channel.perform('connect_printer', { port: port })
    
    // Actualizar la impresora "configurada" localmente
    this.configuredPrinterPort = port

    // Marcar que queremos guardar automáticamente si se conecta con éxito
    this.pendingPrinterAutoSave = true
  }

  disconnectPrinter() {
    this.log("Desconectando impresora...")
    this.channel.perform('disconnect_printer', {})
    this.pendingPrinterAutoSave = false
  }

  updateConfig() {
    const scalePort = this.scalePortTarget.value
    const printerPort = this.printerPortTarget.value

    this.log(`Enviando nueva configuración: Báscula=${scalePort}, Impresora=${printerPort}`)
    this.channel.perform('update_config', {
      scale_port: scalePort,
      printer_port: printerPort
    })
  }

  autoSaveSettings(type) {
    const scalePort = this.scalePortTarget.value
    const printerPort = this.printerPortTarget.value
    
    this.log(`Auto-guardando configuración (${type})...`)
    
    const formData = new FormData()
    formData.append('company[serial_port]', scalePort)
    formData.append('company[printer_port]', printerPort)
    
    // Get authenticity token from meta tags
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    
    fetch('/admin/configurations/auto_save', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': token,
        'Accept': 'application/json'
      },
      body: formData
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.log("✓ Configuración guardada automáticamente en la base de datos.")
      } else {
        this.log(`✗ Error en auto-guardado: ${data.message}`)
      }
    })
    .catch(error => {
      this.log(`✗ Error de red en auto-guardado: ${error.message}`)
    })
  }

  // --- Métodos que actualizan la UI ---
  handleStatusUpdate(data) {
    this.log(`handleStatusUpdate llamado con: ${JSON.stringify(data)}`);
    
    // Store configured ports
    if (data.scale_port) this.configuredScalePort = data.scale_port;
    if (data.printer_port) this.configuredPrinterPort = data.printer_port;

    // Detectar si hubo un cambio a "conectado" para disparar el auto-guardado
    const scaleJustConnected = data.scale_connected && !this.lastScaleState
    const printerJustConnected = data.printer_connected && !this.lastPrinterState
    
    this.lastScaleState = !!data.scale_connected
    this.lastPrinterState = !!data.printer_connected

    this.updateScaleStatus(data.scale_connected ? `Conectada en ${data.scale_port}` : "Desconectada", data.scale_connected ? "success" : "error")
    this.updatePrinterStatus(data.printer_connected ? `Conectada en ${data.printer_port}` : "Desconectada", data.printer_connected ? "success" : "error")

    if ((scaleJustConnected && this.pendingScaleAutoSave) || (printerJustConnected && this.pendingPrinterAutoSave)) {
      this.autoSaveSettings(scaleJustConnected ? "Scale" : "Printer")
      if (scaleJustConnected) this.pendingScaleAutoSave = false
      if (printerJustConnected) this.pendingPrinterAutoSave = false
    }

    // Trigger UI update
    this.renderDropdowns();
  }

  handlePortsUpdate(data) {
    this.log(`¡LISTA DE PUERTOS RECIBIDA!: ${data?.ports ? data.ports.length : 0} encontrados`);
    this.log(`DATOS COMPLETOS RECIBIDOS EN HANDLER:`, JSON.stringify(data));
    
    // Ensure we handle both the direct array (old) and the object (new)
    const ports = Array.isArray(data) ? data : (data?.ports || []);
    this.availablePorts = ports;
    
    if (data && typeof data === 'object' && !Array.isArray(data)) {
      if (data.scale_port) this.configuredScalePort = data.scale_port;
      if (data.printer_port) this.configuredPrinterPort = data.printer_port;

      // Actualizar indicadores de estado si vienen en el mensaje
      if (data.hasOwnProperty('scale_connected')) {
        this.updateScaleStatus(data.scale_connected ? `Conectada en ${data.scale_port}` : "Desconectada", data.scale_connected ? "success" : "error");
      }
      if (data.hasOwnProperty('printer_connected')) {
        this.updatePrinterStatus(data.printer_connected ? `Conectada en ${data.printer_port}` : "Desconectada", data.printer_connected ? "success" : "error");
      }
    }
    
    this.renderDropdowns();
  }

  renderDropdowns() {
    this.log(`renderDropdowns: disponible=${this.availablePorts.length}, scale_saved=${this.configuredScalePort}, printer_saved=${this.configuredPrinterPort}`);

    // 1. Get all detected options for both
    const detectedOptions = this.availablePorts.map(p => ({ 
      device: p.device, 
      description: p.description, 
      source: 'detected' 
    }));
    
    let scaleOptions = [...detectedOptions];
    let printerOptions = [...detectedOptions];

    // 2. Add configured ports if missing
    if (this.configuredScalePort && !scaleOptions.some(p => p.device === this.configuredScalePort)) {
      scaleOptions.push({
        device: this.configuredScalePort,
        description: `${this.configuredScalePort} (guardado)`,
        source: 'saved'
      });
    }

    if (this.configuredPrinterPort && !printerOptions.some(p => p.device === this.configuredPrinterPort)) {
      printerOptions.push({
        device: this.configuredPrinterPort,
        description: `${this.configuredPrinterPort} (guardado)`,
        source: 'saved'
      });
    }

    // 3. Update Scale Dropdown
    if (this.hasScalePortTarget) {
      this.populateSelect(this.scalePortTarget, scaleOptions, "Seleccionar puerto...", this.configuredScalePort);
    }

    // 4. Update Printer Dropdown
    if (this.hasPrinterPortTarget) {
      this.populateSelect(this.printerPortTarget, printerOptions, "Seleccionar impresora...", this.configuredPrinterPort);
    }
  }

  populateSelect(target, options, placeholder, selectedValue) {
    const fragment = document.createDocumentFragment();

    // Default option
    const defaultOption = document.createElement('option');
    defaultOption.value = "";
    defaultOption.textContent = placeholder;
    fragment.appendChild(defaultOption);

    options.forEach(port => {
      const option = document.createElement('option');
      option.value = port.device;
      option.textContent = (port.source === 'saved') ? port.description : `${port.device} - ${port.description}`;
      fragment.appendChild(option);
    });

    // Apply to DOM
    target.innerHTML = '';
    target.appendChild(fragment);

    // Set value if valid
    if (selectedValue && options.some(o => o.device === selectedValue)) {
      target.value = selectedValue;
    } else if (options.length > 0 && !target.value) {
      // If no valid selection and we have options, maybe pick first detected if it's the only one?
      // For now, let's just keep it on placeholder or the first if it was already selected
    }
  }


  updateWeight(weight, timestamp) {
    if (this.hasWeightTarget) {
      const formattedTime = new Date(timestamp).toLocaleTimeString()
      this.weightTarget.innerHTML = `
        <div class="text-3xl font-bold text-emerald-600">${weight}</div>
        <div class="text-sm text-center text-gray-500">${formattedTime}</div>
      `
    }
  }

  log(message, type = 'info') {
    const timestamp = new Date().toLocaleTimeString();
    console.log(`[SerialController] [${timestamp}] ${message}`);

    if (this.hasLogsTarget) {
      const logEntry = document.createElement('div');
      
      const colorClass = {
        'info': 'text-green-400',
        'success': 'text-green-300 font-bold',
        'error': 'text-red-400 font-bold',
        'warning': 'text-yellow-400'
      }[type] || 'text-green-400';
      
      logEntry.className = `${colorClass} mb-1`;
      logEntry.innerHTML = `<span class="opacity-50">[${timestamp}]</span> ${message}`;
      
      this.logsTarget.appendChild(logEntry);
      this.logsTarget.scrollTop = this.logsTarget.scrollHeight;
      
      // Keep only last 100 entries
      while (this.logsTarget.children.length > 100) {
        this.logsTarget.removeChild(this.logsTarget.firstChild);
      }
    }
  }

  updateStatus(message, type) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      // Remover clases anteriores
      this.statusTarget.classList.remove('bg-green-100', 'text-green-800', 'bg-yellow-100', 'text-yellow-800', 'bg-red-100', 'text-red-800', 'bg-blue-100', 'text-blue-800')

      // Agregar clases según el tipo
      switch (type) {
        case 'success':
          this.statusTarget.classList.add('bg-green-100', 'text-green-800')
          break
        case 'warning':
          this.statusTarget.classList.add('bg-yellow-100', 'text-yellow-800')
          break
        case 'error':
          this.statusTarget.classList.add('bg-red-100', 'text-red-800')
          break
        default:
          this.statusTarget.classList.add('bg-blue-100', 'text-blue-800')
      }
    }
  }

  updateScaleStatus(message, type) {
    if (this.hasScaleStatusTarget) {
      this.scaleStatusTarget.textContent = message
      // Remover clases anteriores
      this.scaleStatusTarget.classList.remove('bg-green-100', 'text-green-800', 'bg-red-100', 'text-red-800', 'bg-gray-100', 'text-gray-800')

      // Agregar clases según el tipo
      switch (type) {
        case 'success':
          this.scaleStatusTarget.classList.add('bg-green-100', 'text-green-800')
          break
        case 'error':
          this.scaleStatusTarget.classList.add('bg-red-100', 'text-red-800')
          break
        default:
          this.scaleStatusTarget.classList.add('bg-gray-100', 'text-gray-800')
      }
    }
  }

  updatePrinterStatus(message, type) {
    if (this.hasPrinterStatusTarget) {
      this.printerStatusTarget.textContent = message
      // Remover clases anteriores
      this.printerStatusTarget.classList.remove('bg-green-100', 'text-green-800', 'bg-red-100', 'text-red-800', 'bg-gray-100', 'text-gray-800')

      // Agregar clases según el tipo
      switch (type) {
        case 'success':
          this.printerStatusTarget.classList.add('bg-green-100', 'text-green-800')
          break
        case 'error':
          this.printerStatusTarget.classList.add('bg-red-100', 'text-red-800')
          break
        default:
          this.printerStatusTarget.classList.add('bg-gray-100', 'text-gray-800')
      }
    }
  }
}
