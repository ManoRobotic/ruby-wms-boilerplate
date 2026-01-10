import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

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
    switch (data.action) {
      case 'weight_update':
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
        this.handlePortsUpdate(data.ports)
        break
      case 'set_config': // Confirmación del servidor
        this.log(`Configuración confirmada por el servidor.`)
        this.handleStatusUpdate(data)
        break
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
    if (this.hasScalePortTarget) {
      const currentScale = this.scalePortTarget.value
      this.scalePortTarget.innerHTML = '<option value="">Seleccionar puerto...</option>'
      ports.filter(p => p.device.toLowerCase().includes('com') || p.device.toLowerCase().includes('tty')).forEach(port => {
        const option = document.createElement('option')
        option.value = port.device
        option.textContent = `${port.device} - ${port.description}`
        this.scalePortTarget.appendChild(option)
      })
      if (ports.some(p => p.device === currentScale)) {
        this.scalePortTarget.value = currentScale
      }
    }
    
    if (this.hasPrinterPortTarget) {
        const currentPrinter = this.printerPortTarget.value
        this.printerPortTarget.innerHTML = '<option value="">Seleccionar impresora...</option>'
        // Para impresoras, especialmente en Windows, listamos todo lo que no es un puerto COM.
        ports.filter(p => !p.device.toLowerCase().includes('com') && !p.device.toLowerCase().includes('tty')).forEach(port => {
            const option = document.createElement('option')
            option.value = port.device
            option.textContent = port.description
            this.printerPortTarget.appendChild(option)
        })
        if (ports.some(p => p.device === currentPrinter)) {
            this.printerPortTarget.value = currentPrinter
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

  updateStatus(message, type) { /* ... */ }
  updateScaleStatus(message, type) { /* ... */ }
  updatePrinterStatus(message, type) { /* ... */ }
}
