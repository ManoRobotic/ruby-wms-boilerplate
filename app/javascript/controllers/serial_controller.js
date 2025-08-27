import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "weight", "port", "logs", "printerStatus"]
  static values = { 
    baseUrl: String,
    autoConnect: Boolean,
    pollInterval: Number 
  }

  connect() {
    this.baseUrlValue = this.baseUrlValue || "/api/serial"
    this.pollIntervalValue = this.pollIntervalValue || 2000
    this.isPolling = false
    
    if (this.autoConnectValue) {
      this.checkHealth()
    }
    
    this.log("Serial controller initialized")
  }

  disconnect() {
    this.stopPolling()
  }

  async checkHealth() {
    try {
      const response = await fetch(`${this.baseUrlValue}/health`)
      const data = await response.json()
      
      if (data.status === 'healthy') {
        this.updateStatus("✓ Serial server connected", "success")
        await this.loadPorts()
      } else {
        this.updateStatus("✗ Serial server unavailable", "error")
      }
    } catch (error) {
      this.updateStatus("✗ Cannot reach serial server", "error")
      this.log(`Health check error: ${error.message}`)
    }
  }

  async loadPorts() {
    try {
      const response = await fetch(`${this.baseUrlValue}/ports`)
      const data = await response.json()
      
      if (data.status === 'success' && this.hasPortTarget) {
        this.portTarget.innerHTML = '<option value="">Select port...</option>'
        data.ports.forEach(port => {
          const option = document.createElement('option')
          option.value = port.device
          option.textContent = `${port.device} - ${port.description}`
          this.portTarget.appendChild(option)
        })
      }
    } catch (error) {
      this.log(`Error loading ports: ${error.message}`)
    }
  }

  async connectScale(event) {
    event.preventDefault()
    
    const port = this.hasPortTarget ? this.portTarget.value : '/dev/ttyS0'
    const baudrate = 115200
    
    if (!port) {
      this.updateStatus("Please select a port", "error")
      return
    }

    try {
      const response = await fetch(`${this.baseUrlValue}/connect_scale`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ port, baudrate })
      })
      
      const data = await response.json()
      
      if (data.status === 'success') {
        this.updateStatus("✓ Scale connected", "success")
        this.log(`Scale connected on ${port}`)
        await this.startReading()
      } else {
        this.updateStatus("✗ Failed to connect scale", "error")
        this.log(`Connection failed: ${data.message}`)
      }
    } catch (error) {
      this.updateStatus("✗ Connection error", "error")
      this.log(`Error: ${error.message}`)
    }
  }

  async disconnectScale(event) {
    event.preventDefault()
    
    try {
      this.stopPolling()
      
      const response = await fetch(`${this.baseUrlValue}/disconnect_scale`, {
        method: 'POST'
      })
      
      const data = await response.json()
      
      if (data.status === 'success') {
        this.updateStatus("Scale disconnected", "info")
        this.updateWeight("--", "--")
        this.log("Scale disconnected")
      }
    } catch (error) {
      this.log(`Error disconnecting: ${error.message}`)
    }
  }

  async startReading() {
    try {
      const response = await fetch(`${this.baseUrlValue}/start_scale`, {
        method: 'POST'
      })
      
      const data = await response.json()
      
      if (data.status === 'success') {
        this.startPolling()
        this.log("Started continuous reading")
      }
    } catch (error) {
      this.log(`Error starting reading: ${error.message}`)
    }
  }

  async stopReading() {
    try {
      this.stopPolling()
      
      const response = await fetch(`${this.baseUrlValue}/stop_scale`, {
        method: 'POST'
      })
      
      const data = await response.json()
      this.log("Stopped continuous reading")
    } catch (error) {
      this.log(`Error stopping reading: ${error.message}`)
    }
  }

  startPolling() {
    if (this.isPolling) return
    
    this.isPolling = true
    this.pollTimer = setInterval(() => {
      this.getLatestReadings()
    }, this.pollIntervalValue)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
    }
    this.isPolling = false
  }

  async getLatestReadings() {
    try {
      const response = await fetch(`${this.baseUrlValue}/latest_readings`)
      const data = await response.json()
      
      if (data.status === 'success' && data.readings.length > 0) {
        const latest = data.readings[data.readings.length - 1]
        this.updateWeight(latest.weight, latest.timestamp)
      }
    } catch (error) {
      // Silent error to avoid log spam
    }
  }

  async readWeightNow(event) {
    event.preventDefault()
    
    try {
      const response = await fetch(`${this.baseUrlValue}/get_weight_now?timeout=5`)
      const data = await response.json()
      
      if (data.status === 'success') {
        this.updateWeight(data.weight, data.timestamp)
        this.log(`Weight read: ${data.weight}`)
        
        // Disparar evento personalizado con el peso
        this.dispatch('weightRead', { 
          detail: { weight: data.weight, timestamp: data.timestamp } 
        })
      } else {
        this.log("No weight reading available")
      }
    } catch (error) {
      this.log(`Error reading weight: ${error.message}`)
    }
  }

  async connectPrinter(event) {
    event.preventDefault()
    
    try {
      const response = await fetch(`${this.baseUrlValue}/connect_printer`, {
        method: 'POST'
      })
      
      const data = await response.json()
      
      if (data.status === 'success') {
        this.updatePrinterStatus("✓ Printer connected", "success")
        this.log("Printer connected")
      } else {
        this.updatePrinterStatus("✗ Failed to connect printer", "error")
        this.log(`Printer connection failed: ${data.message}`)
      }
    } catch (error) {
      this.updatePrinterStatus("✗ Connection error", "error")
      this.log(`Error: ${error.message}`)
    }
  }

  async printLabel(event) {
    event.preventDefault()
    
    const content = event.target.dataset.content || "Test Label"
    const ancho_mm = event.target.dataset.ancho || 80
    const alto_mm = event.target.dataset.alto || 50
    
    try {
      const response = await fetch(`${this.baseUrlValue}/print_label`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          content, 
          ancho_mm: parseInt(ancho_mm), 
          alto_mm: parseInt(alto_mm) 
        })
      })
      
      const data = await response.json()
      
      if (data.status === 'success') {
        this.log(`Label printed: ${content} (${ancho_mm}x${alto_mm}mm)`)
        
        // Disparar evento personalizado
        this.dispatch('labelPrinted', { 
          detail: { content, ancho_mm, alto_mm } 
        })
      } else {
        this.log(`Print failed: ${data.message}`)
      }
    } catch (error) {
      this.log(`Print error: ${error.message}`)
    }
  }

  async testPrinter(event) {
    event.preventDefault()
    
    const ancho_mm = event.target.dataset.ancho || 80
    const alto_mm = event.target.dataset.alto || 50
    
    try {
      const response = await fetch(`${this.baseUrlValue}/test_printer`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          ancho_mm: parseInt(ancho_mm), 
          alto_mm: parseInt(alto_mm) 
        })
      })
      
      const data = await response.json()
      
      if (data.status === 'success') {
        this.log(`Printer test executed (${ancho_mm}x${alto_mm}mm)`)
      } else {
        this.log(`Test failed: ${data.message}`)
      }
    } catch (error) {
      this.log(`Test error: ${error.message}`)
    }
  }

  // Método para imprimir desde otros controllers
  async printCustomLabel(content, ancho_mm = 80, alto_mm = 50) {
    try {
      const response = await fetch(`${this.baseUrlValue}/print_label`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ 
          content, 
          ancho_mm: parseInt(ancho_mm), 
          alto_mm: parseInt(alto_mm) 
        })
      })
      
      const data = await response.json()
      
      if (data.status === 'success') {
        this.log(`Custom label printed: ${content} (${ancho_mm}x${alto_mm}mm)`)
      } else {
        this.log(`Print failed: ${data.message}`)
      }
      
      return data.status === 'success'
    } catch (error) {
      this.log(`Print error: ${error.message}`)
      return false
    }
  }

  // Método para obtener peso desde otros controllers
  async getCurrentWeight(timeout = 5) {
    try {
      const response = await fetch(`${this.baseUrlValue}/get_weight_now?timeout=${timeout}`)
      const data = await response.json()
      
      if (data.status === 'success') {
        return { weight: data.weight, timestamp: data.timestamp }
      }
      return null
    } catch (error) {
      return null
    }
  }

  updateStatus(message, type = "info") {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      this.statusTarget.className = `status ${type}`
    }
  }

  updateWeight(weight, timestamp) {
    if (this.hasWeightTarget) {
      // Agregar animación de loading mientras se actualiza
      this.weightTarget.innerHTML = `
        <div class="text-2xl font-bold text-center text-blue-500 weight-loading">Leyendo...</div>
        <div class="text-sm text-center text-gray-500">--</div>
      `
      
      // Después de un breve delay, mostrar el peso con animación
      setTimeout(() => {
        this.weightTarget.innerHTML = `
          <div class="text-2xl font-bold text-center text-gray-400">${weight}</div>
          <div class="text-sm text-center text-gray-500">${timestamp}</div>
        `
        
        // Trigger weight animation by removing and adding class
        const weightDisplay = this.weightTarget.querySelector('.text-2xl')
        if (weightDisplay && weight !== '--') {
          weightDisplay.classList.remove('text-gray-400')
          weightDisplay.classList.add('text-emerald-600')
          
          // Apply pulse animation
          setTimeout(() => {
            weightDisplay.style.animation = 'weightPulse 0.8s ease-in-out'
          }, 50)
        }
      }, 300)
    }
  }

  updatePrinterStatus(message, type = "info") {
    if (this.hasPrinterStatusTarget) {
      this.printerStatusTarget.textContent = message
      this.printerStatusTarget.className = `printer-status ${type}`
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
      
      this.logsTarget.appendChild(logLine)
      this.logsTarget.scrollTop = this.logsTarget.scrollHeight
      
      // Mantener solo las últimas 50 líneas
      while (this.logsTarget.children.length > 50) {
        this.logsTarget.removeChild(this.logsTarget.firstChild)
      }
    }
  }

  clearLogs() {
    if (this.hasLogsTarget) {
      this.logsTarget.innerHTML = ''
    }
  }
}