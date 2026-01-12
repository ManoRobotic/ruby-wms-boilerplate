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
          this.log(`Datos recibidos: ${JSON.stringify(data)}`)
          this.route_action(data)
        }
      }
    )
  }

  // --- Enrutador de Acciones ---
  route_action(data) {
    try {
      this.log(`Acción recibida: ${data.action}`);
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
          this.log(`Actualización de estado recibida`);
          this.handleStatusUpdate(data)
          break
        case 'ports_update':
          this.log(`Actualización de puertos recibida:`, data);
          this.handlePortsUpdate(data.ports)
          break
        case 'set_config': // Confirmación del servidor
          this.log(`Configuración confirmada por el servidor: ${JSON.stringify(data)}`)
          this.handleStatusUpdate(data)
          break
        default:
          this.log(`Acción desconocida recibida: ${data.action}`)
      }
    } catch (error) {
      this.log(`Error procesando acción '${data.action}':`, error);
      console.error('Error in route_action:', error);
    }
  }

  // --- Acciones que envían datos al backend ---
  updateConfig() {
    const scalePort = this.scalePortTarget.value
    const printerPort = this.printerPortTarget.value
    
    this.log(`Enviando nueva configuración: Báscula=${scalePort}, Impresora=${printerPort}`)
    this.channel.perform('update_config', {
      scale_port: scalePort,
      printer_port: printerPort
    })
  }

  // --- Métodos que actualizan la UI ---
  handleStatusUpdate(data) {
    if (this.hasScalePortTarget && data.scale_port) {
      this.scalePortTarget.value = data.scale_port
    }
    if (this.hasPrinterPortTarget && data.printer_port) {
      this.printerPortTarget.value = data.printer_port
    }
    
    this.updateScaleStatus(data.scale_connected ? `Conectada en ${data.scale_port}` : "Desconectada", data.scale_connected ? "success" : "error")
    this.updatePrinterStatus(data.printer_connected ? `Conectada en ${data.printer_port}` : "Desconectada", data.printer_connected ? "success" : "error")
  }
  
  handlePortsUpdate(ports) {
    // Defensive check to prevent errors if ports is undefined/null
    if (!ports || !Array.isArray(ports)) {
      this.log(`Advertencia: handlePortsUpdate recibió datos inválidos: ${typeof ports}`, ports);
      return;
    }

    this.log(`Actualizando puertos, total de puertos: ${ports.length}`);

    if (this.hasScalePortTarget) {
      const currentScale = this.scalePortTarget.value
      // Create a document fragment for efficient DOM updates
      const fragment = document.createDocumentFragment();

      // Add default option
      const defaultOption = document.createElement('option');
      defaultOption.value = "";
      defaultOption.textContent = "Seleccionar puerto...";
      fragment.appendChild(defaultOption);

      const scalePorts = ports.filter(p =>
        p.device &&
        (p.device.toLowerCase().includes('com') ||
        p.device.toLowerCase().includes('tty') ||
        p.device.toLowerCase().includes('/dev/tty') ||
        p.device.toLowerCase().includes('/dev/cu'))
      );

      this.log(`Puertos de báscula encontrados: ${scalePorts.length}`);

      scalePorts.forEach(port => {
        if (port.device && port.description !== undefined) {
          const option = document.createElement('option');
          option.value = port.device;
          option.textContent = `${port.device} - ${port.description}`;
          fragment.appendChild(option);
        }
      });

      // Apply all changes at once to minimize DOM reflows
      this.scalePortTarget.innerHTML = '';
      this.scalePortTarget.appendChild(fragment);

      // Si el puerto actual está en la lista, mantenerlo seleccionado
      if (scalePorts.some(p => p.device === currentScale)) {
        this.scalePortTarget.value = currentScale;
      } else if (scalePorts.length > 0) {
        // Si hay puertos disponibles y ninguno está seleccionado, seleccionar el primero
        this.scalePortTarget.value = scalePorts[0].device;
      }
    }

    if (this.hasPrinterPortTarget) {
      const currentPrinter = this.printerPortTarget.value
      // Create a document fragment for efficient DOM updates
      const fragment = document.createDocumentFragment();

      // Add default option
      const defaultOption = document.createElement('option');
      defaultOption.value = "";
      defaultOption.textContent = "Seleccionar impresora...";
      fragment.appendChild(defaultOption);

      // Para impresoras, listamos todo lo que no es un puerto serial típico
      const printerPorts = ports.filter(p =>
        p.device &&
        !p.device.toLowerCase().includes('com') &&
        !p.device.toLowerCase().includes('tty') &&
        !p.device.toLowerCase().includes('/dev/tty') &&
        !p.device.toLowerCase().includes('/dev/cu')
      );

      this.log(`Puertos de impresora encontrados: ${printerPorts.length}`);

      printerPorts.forEach(port => {
        if (port.device && port.description !== undefined) {
          const option = document.createElement('option');
          option.value = port.device;
          option.textContent = port.description;
          fragment.appendChild(option);
        }
      });

      // Apply all changes at once to minimize DOM reflows
      this.printerPortTarget.innerHTML = '';
      this.printerPortTarget.appendChild(fragment);

      // Si el puerto actual está en la lista, mantenerlo seleccionado
      if (printerPorts.some(p => p.device === currentPrinter)) {
        this.printerPortTarget.value = currentPrinter;
      } else if (printerPorts.length > 0) {
        // Si hay puertos disponibles y ninguno está seleccionado, seleccionar el primero
        this.printerPortTarget.value = printerPorts[0].device;
      }
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
  
  log(message) {
    console.log(`[SerialController] ${message}`)
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
