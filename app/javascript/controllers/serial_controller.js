import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer" // Asegúrate que la ruta al consumer sea correcta

export default class extends Controller {
  static targets = ["status", "weight", "logs", "printerStatus", "scaleStatus", "readButton"]
  static values = { 
    deviceId: String // El ID del dispositivo se pasará desde la vista de Rails
  }

  connect() {
    this.log("Inicializando controlador Serial (versión Action Cable)...")
    if (!this.hasDeviceIdValue || this.deviceIdValue.length === 0) {
      this.updateStatus("✗ Error: No se proporcionó un ID de dispositivo.", "error")
      this.log("Error: el `device-id-value` es requerido para la conexión.")
      return
    }

    this.initActionCable()
  }

  disconnect() {
    if (this.channel) {
      this.log("Desuscribiéndose del canal de Action Cable.")
      consumer.subscriptions.remove(this.channel)
    }
  }

  initActionCable() {
    this.log(`Intentando suscribirse a SerialConnectionChannel con device_id: ${this.deviceIdValue}`)
    
    this.channel = consumer.subscriptions.create(
      { channel: "SerialConnectionChannel", device_id: this.deviceIdValue },
      {
        // Se llama una vez cuando la suscripción se establece.
        connected: () => {
          this.log("✓ Conectado y suscrito a SerialConnectionChannel.")
          this.updateStatus("✓ Conectado en tiempo real", "success")
          // Solicitar el estado actual del dispositivo al conectarse.
          this.requestStatus()
        },

        // Se llama cuando la conexión se pierde.
        disconnected: () => {
          this.log("↻ Desconectado del canal. Action Cable intentará reconectar.")
          this.updateStatus("↻ Desconectado, intentando reconectar...", "warning")
          this.updateScaleStatus("Desconocido", "warning")
          this.updatePrinterStatus("Desconocido", "warning")
        },

        // Se llama cuando se reciben datos del backend.
        received: (data) => {
          this.log(`Datos recibidos: ${JSON.stringify(data)}`)
          
          // Enrutador de acciones basado en el contenido del mensaje
          switch (data.action) {
            case 'weight_update':
              this.updateWeight(data.weight, data.timestamp)
              break
            case 'status_update':
              this.handleStatusUpdate(data)
              break
            case 'print_status':
              this.log(`Estado de impresión recibido: ${data.status}`)
              break
            default:
              this.log(`Acción desconocida recibida: ${data.action}`)
          }
        }
      }
    )
  }

  // --- Acciones que envían datos al backend ---

  /**
   * Envía un comando de impresión a través del canal de Action Cable.
   */
  printLabel(event) {
    event.preventDefault()
    
    const content = event.target.dataset.content || "Test Label"
    const ancho_mm = event.target.dataset.ancho || 80
    const alto_mm = event.target.dataset.alto || 50

    this.log(`Enviando comando de impresión: ${ancho_mm}x${alto_mm}mm`)
    this.channel.perform('receive', {
      action: 'print_label',
      content: content,
      ancho_mm: parseInt(ancho_mm),
      alto_mm: parseInt(alto_mm)
    })
  }

  /**
    * Envía una solicitud para obtener el estado actual del dispositivo.
    */
  requestStatus() {
    this.log("Solicitando estado actual del dispositivo...")
    this.updateStatus("↻ Solicitando estado...", "info")
    this.channel.perform('receive', {
      action: 'request_status'
    })
  }

  // --- Métodos que actualizan la UI ---

  handleStatusUpdate(data) {
    this.log("Actualizando estado de los dispositivos.")
    if (data.scale_connected) {
      this.updateScaleStatus("Conectada", "success")
    } else {
      this.updateScaleStatus("Desconectada", "error")
    }

    if (data.printer_connected) {
      this.updatePrinterStatus(`Conectada (${data.printer_name})`, "success")
    } else {
      this.updatePrinterStatus("Desconectada", "error")
    }
    this.updateStatus("✓ Estado actualizado", "success")
  }
  
  updateStatus(message, type = "info") {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      const classMap = {
        success: "bg-green-100 text-green-800",
        error: "bg-red-100 text-red-800",
        warning: "bg-yellow-100 text-yellow-800",
        info: "bg-blue-100 text-blue-800"
      }
      this.statusTarget.className = `px-2 py-1 rounded text-sm font-medium ${classMap[type] || classMap['info']}`
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

  updateScaleStatus(message, type = "info") {
    if (this.hasScaleStatusTarget) {
      this.scaleStatusTarget.textContent = message
      const classMap = {
        success: "bg-green-100 text-green-800",
        error: "bg-red-100 text-red-800",
        warning: "bg-yellow-100 text-yellow-800",
        info: "bg-gray-100 text-gray-800"
      }
      this.scaleStatusTarget.className = `px-2 py-1 rounded text-sm font-medium ${classMap[type] || classMap['info']}`
    }
  }

  updatePrinterStatus(message, type = "info") {
    if (this.hasPrinterStatusTarget) {
      this.printerStatusTarget.textContent = message
      const classMap = {
        success: "bg-green-100 text-green-800",
        error: "bg-red-100 text-red-800",
        warning: "bg-yellow-100 text-yellow-800",
        info: "bg-gray-100 text-gray-800"
      }
      this.printerStatusTarget.className = `px-2 py-1 rounded text-sm font-medium ${classMap[type] || classMap['info']}`
    }
  }

  log(message) {
    const timestamp = new Date().toLocaleTimeString()
    const logMessage = `[${timestamp}] ${message}`
    
    console.log(logMessage)
    
    if (this.hasLogsTarget) {
      const logLine = document.createElement('div')
      logLine.textContent = logMessage
      logLine.className = 'log-line'
      this.logsTarget.insertBefore(logLine, this.logsTarget.firstChild)
      
      while (this.logsTarget.children.length > 50) {
        this.logsTarget.removeChild(this.logsTarget.lastChild)
      }
    }
  }
}