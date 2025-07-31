import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="printer"
export default class extends Controller {
  static targets = ["connectButton", "calibrateButton", "statusButton", "printButton", "statusIndicator", "statusText"]

  connect() {
    console.log("🖨️ PRINTER CONTROLLER CONNECTED! 🖨️")
    this.isConnected = false
    this.updateConnectionStatus(false)
    
    // Agregar logs para debug
    console.log("Printer controller targets found:", this.hasConnectButtonTarget)
    
    // Agregar un click listener como fallback
    if (this.hasConnectButtonTarget) {
      console.log("✅ Connect button target found")
    } else {
      console.error("❌ Connect button target NOT found")
    }
  }

  async connectPrinter() {
    console.log("🚀 CONNECT PRINTER BUTTON CLICKED! 🚀")
    console.log("Connecting to printer...")
    this.updateStatus("Conectando...", "connecting")
    this.connectButtonTarget.disabled = true
    
    try {
      const response = await this.makeRequest('/admin/manual_printing/connect_printer')
      
      if (response.success) {
        this.isConnected = true
        this.updateConnectionStatus(true)
        this.updateStatus("Impresora conectada", "connected")
        this.connectButtonTarget.textContent = "✓ Conectada"
        this.connectButtonTarget.disabled = true
        
        // Habilitar otros botones
        this.calibrateButtonTarget.disabled = false
        this.statusButtonTarget.disabled = false
        this.printButtonTarget.disabled = false
        
        this.addToLog(`Impresora conectada: ${response.output}`, 'success')
      } else {
        this.updateConnectionStatus(false)
        this.updateStatus("Error de conexión", "error")
        this.connectButtonTarget.disabled = false
        this.addToLog(`Error conectando impresora: ${response.error}`, 'error')
      }
    } catch (error) {
      this.updateConnectionStatus(false)
      this.updateStatus("Error de conexión", "error")
      this.connectButtonTarget.disabled = false
      this.addToLog(`Error de conexión: ${error.message}`, 'error')
    }
  }

  async calibrateSensor() {
    if (!this.isConnected) {
      this.addToLog("Impresora no conectada", 'warning')
      return
    }
    
    console.log("Calibrating sensor...")
    this.calibrateButtonTarget.disabled = true
    
    try {
      const response = await this.makeRequest('/admin/manual_printing/calibrate_sensor')
      
      if (response.success) {
        this.addToLog(`Sensor calibrado: ${response.output}`, 'success')
      } else {
        this.addToLog(`Error calibrando sensor: ${response.error}`, 'error')
      }
    } catch (error) {
      this.addToLog(`Error calibrando sensor: ${error.message}`, 'error')
    } finally {
      this.calibrateButtonTarget.disabled = false
    }
  }

  async checkStatus() {
    if (!this.isConnected) {
      this.addToLog("Impresora no conectada", 'warning')
      return
    }
    
    console.log("Checking printer status...")
    this.statusButtonTarget.disabled = true
    
    try {
      const response = await this.makeRequest('/admin/manual_printing/printer_status')
      
      if (response.success) {
        this.addToLog(`Estado de impresora: ${response.output}`, 'info')
      } else {
        this.addToLog(`Error obteniendo estado: ${response.error}`, 'error')
      }
    } catch (error) {
      this.addToLog(`Error obteniendo estado: ${error.message}`, 'error')
    } finally {
      this.statusButtonTarget.disabled = false
    }
  }

  updateConnectionStatus(connected) {
    if (connected) {
      this.statusIndicatorTarget.className = "w-3 h-3 rounded-full bg-green-500 mr-3"
      this.statusTextTarget.textContent = "Impresora conectada"
    } else {
      this.statusIndicatorTarget.className = "w-3 h-3 rounded-full bg-red-500 mr-3"
      this.statusTextTarget.textContent = "Impresora desconectada"
    }
  }

  updateStatus(message, type) {
    this.statusTextTarget.textContent = message
    
    // Cambiar color del indicador según el tipo
    switch (type) {
      case 'connected':
        this.statusIndicatorTarget.className = "w-3 h-3 rounded-full bg-green-500 mr-3"
        break
      case 'connecting':
        this.statusIndicatorTarget.className = "w-3 h-3 rounded-full bg-blue-500 mr-3"
        break
      case 'error':
        this.statusIndicatorTarget.className = "w-3 h-3 rounded-full bg-red-500 mr-3"
        break
      default:
        this.statusIndicatorTarget.className = "w-3 h-3 rounded-full bg-gray-500 mr-3"
    }
  }

  async makeRequest(url, data = {}) {
    const formData = new FormData()
    Object.keys(data).forEach(key => {
      formData.append(key, data[key])
    })

    // Agregar token CSRF
    const token = document.querySelector('meta[name="csrf-token"]').getAttribute('content')
    formData.append('authenticity_token', token)

    const response = await fetch(url, {
      method: 'POST',
      body: formData,
      headers: {
        'X-Requested-With': 'XMLHttpRequest'
      }
    })

    return response.json()
  }

  addToLog(message, type = 'info') {
    // Buscar el log de actividad en la página
    const activityLog = document.getElementById('activity-log')
    if (!activityLog) return

    const timestamp = new Date().toLocaleTimeString()
    const colorClass = {
      'info': 'text-blue-400',
      'success': 'text-green-400',
      'error': 'text-red-400',
      'warning': 'text-yellow-400'
    }[type] || 'text-gray-400'
    
    const logEntry = document.createElement('div')
    logEntry.className = colorClass
    logEntry.innerHTML = `[${timestamp}] 🖨️ ${message}`
    
    activityLog.appendChild(logEntry)
    activityLog.scrollTop = activityLog.scrollHeight
  }

  clearLog() {
    console.log("🧹 CLEAR LOG BUTTON CLICKED! 🧹")
    const activityLog = document.getElementById('activity-log')
    if (activityLog) {
      activityLog.innerHTML = '<div class="text-gray-500">Sistema de impresión inicializado...</div>'
      console.log("✅ Log cleared successfully")
    } else {
      console.error("❌ Activity log element not found")
    }
  }
}