import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "weight", "portSelect", "readBtn", "autoSaveCheckbox"]
  static values = { 
    baseUrl: String,
    savedPort: String,
    autoSave: Boolean
  }

  connect() {
    this.baseUrlValue = this.baseUrlValue || "http://localhost:5000"
    this.checkServerConnection().then(() => {
      this.loadPorts().then(() => {
        if (this.savedPortValue && this.portSelectTarget.value === this.savedPortValue) {
          this.getWeight()
        }
      })
    })

    if (this.hasAutoSaveCheckboxTarget) {
      this.autoSaveCheckboxTarget.checked = this.autoSaveValue
    }
  }

  disconnect() {
    // Cleanup if needed
  }

  async checkServerConnection() {
    try {
      // Try to ping the serial server health endpoint if it exists
      const healthUrl = `${this.baseUrlValue}/health`
      const response = await fetch(healthUrl, {
        method: 'GET',
        headers: {
          'skip_zrok_interstitial': 'true'
        },
        timeout: 5000 // 5 second timeout
      })
      
      if (response.ok) {
        this.updateStatus("Serial server connected", "success")
        return true
      } else {
        this.updateStatus("Serial server disconnected", "error")
        return false
      }
    } catch (error) {
      this.updateStatus("Serial server disconnected", "error")
      return false
    }
  }

  async loadPorts() {
    this.updateStatus("Loading ports...", "info")
    try {
      const response = await fetch(`${this.baseUrlValue}/ports`, {
        headers: {
          'skip_zrok_interstitial': 'true'
        }
      })
      const data = await response.json()
      
      if (data.status === 'success' && this.hasPortSelectTarget) {
        this.portSelectTarget.innerHTML = '<option value="">Select port...</option>'
        data.ports.forEach(port => {
          const option = document.createElement('option')
          option.value = port.device
          option.textContent = `${port.device} - ${port.description}`
          this.portSelectTarget.appendChild(option)
        })
        
        if (this.savedPortValue) {
          this.portSelectTarget.value = this.savedPortValue
        }
        this.updateStatus("Ports loaded", "success")
      }
    } catch (error) {
      // Check if it's a connection error
      if (error.message.includes('Failed to fetch') || error.message.includes('NetworkError')) {
        this.updateStatus("Serial server disconnected - Check connection", "error")
      } else {
        this.updateStatus("Error loading ports - " + error.message, "error")
      }
    }
  }

  async getWeight(event) {
    if (event) event.preventDefault()

    const port = this.portSelectTarget.value
    if (!port) {
      this.updateStatus("Please select a port", "error")
      return
    }

    // Save the selected port
    this.saveConfiguration({ serial_port: port })

    this.showSpinner()
    this.readBtnTarget.disabled = true

    try {
      const reading = await this.readSingleWeight(port)
      this.hideSpinner() // Call hideSpinner here
      if (reading) {
        this.updateWeight(reading.weight, reading.timestamp)
        this.updateStatus("Weight read successfully", "success")
      } else {
        this.updateStatus("Failed to read weight", "error")
      }
    } catch (error) {
      this.hideSpinner() // Also here in case of error
      this.updateStatus(`Error: ${error.message}`, "error")
    } finally {
      this.readBtnTarget.disabled = false
    }
  }

  async readSingleWeight(port) {
    const baudrate = 115200
    let connected = false
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 300000) // 5 minutes timeout

    try {
      // 1. Connect
      this.updateStatus("Connecting...", "info")
      let response = await fetch(`${this.baseUrlValue}/scale/connect`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'skip_zrok_interstitial': 'true' // Add header here
        },
        body: JSON.stringify({ port, baudrate }),
        signal: controller.signal
      })
      let data = await response.json()
      if (data.status !== 'success') {
        throw new Error('Failed to connect to scale')
      }
      connected = true
      this.updateStatus("Connected, waiting for weight...", "info")

      // 2. Read
      response = await fetch(`${this.baseUrlValue}/scale/read`, {
        signal: controller.signal,
        headers: {
          'skip_zrok_interstitial': 'true' // Add header here
        }
      })
      data = await response.json()
      if (data.status !== 'success') {
        throw new Error('Failed to read from scale')
      }
      
      return data

    } finally {
      clearTimeout(timeoutId)
      // 3. Disconnect
      if (connected) {
        await fetch(`${this.baseUrlValue}/scale/disconnect`, { method: 'POST' })
        this.updateStatus("Disconnected", "info")
      }
    }
  }

  showSpinner() {
    if (this.hasWeightTarget) {
      this.originalWeightContent = this.weightTarget.innerHTML
      this.weightTarget.innerHTML = `
        <div class="flex flex-col items-center justify-center py-8">
          <div class="relative">
            <svg class="w-16 h-16 animate-spin text-blue-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
          </div>
          <div class="mt-4 text-center">
            <span class="text-sm text-gray-600 block">Leyendo peso...</span>
          </div>
        </div>
      `
    }
  }

  hideSpinner() {
    if (this.hasWeightTarget && this.originalWeightContent) {
      this.weightTarget.innerHTML = this.originalWeightContent
    }
  }

  updateStatus(message, type = "info") {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      const baseClasses = "px-2 py-1 rounded text-xs font-medium"
      const colorClasses = {
        success: "bg-green-100 text-green-800",
        error: "bg-red-100 text-red-800",
        info: "bg-blue-100 text-blue-800"
      }
      
      // Add special styling for connection status
      if (message.includes("connected")) {
        this.statusTarget.className = `${baseClasses} ${colorClasses.success}`
      } else if (message.includes("disconnected") || message.includes("Error")) {
        this.statusTarget.className = `${baseClasses} ${colorClasses.error}`
      } else {
        this.statusTarget.className = `${baseClasses} ${colorClasses[type] || colorClasses.info}`
      }
    }
  }

  updateWeight(weight, timestamp) {
    if (this.hasWeightTarget) {
      const weightValue = parseFloat(weight) || 0
      const percentage = Math.min(100, Math.max(0, weightValue))
      const strokeOffset = 100 - percentage
      
      let colorClass = "text-blue-600"
      if (percentage > 75) {
        colorClass = "text-red-600"
      } else if (percentage > 50) {
        colorClass = "text-yellow-500"
      }

      this.weightTarget.innerHTML = `
        <div class="flex flex-col items-center justify-center">
          <div class="relative size-40">
            <svg class="size-full -rotate-90" viewBox="0 0 36 36" xmlns="http://www.w3.org/2000/svg">
              <circle cx="18" cy="18" r="16" fill="none" class="stroke-current text-gray-200" stroke-width="2"></circle>
              <circle cx="18" cy="18" r="16" fill="none" class="stroke-current ${colorClass}" stroke-width="2" stroke-dasharray="100" stroke-dashoffset="${strokeOffset}" stroke-linecap="round"></circle>
            </svg>
            <div class="absolute top-1/2 start-1/2 transform -translate-y-1/2 -translate-x-1/2">
              <span class="text-center text-2xl font-bold ${colorClass}">${weightValue.toFixed(2)}</span>
            </div>
          </div>
          <div class="mt-2 text-center">
            <span class="text-sm text-gray-500 block">kg</span>
            <span class="text-xs text-gray-400 block">${timestamp}</span>
          </div>
        </div>
      `
      
      // Dispatch event to notify the form controller
      this.element.dispatchEvent(new CustomEvent('serial:weightRead', {
        detail: { weight: weightValue, timestamp: timestamp },
        bubbles: true
      }));

      if (this.hasAutoSaveCheckboxTarget && this.autoSaveCheckboxTarget.checked) {
        this.element.closest('form').requestSubmit()
      }
    }
  }

  // Método para guardar configuración usando Rails forms
  saveConfiguration(configData) {
    // Enviar una solicitud al endpoint de auto-guardado
    fetch('/admin/configurations/auto_save', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken()
      },
      body: JSON.stringify(configData)
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.log("Configuration saved successfully")
      } else {
        this.log(`Error saving configuration: ${data.message}`)
      }
    })
    .catch(error => {
      this.log(`Error saving configuration: ${error.message}`)
    })
  }

  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }

  log(message) {
    // console.log(`[ConsecutivoScale] ${message}`)
  }

  saveAutoSaveState() {
    if (this.hasAutoSaveCheckboxTarget) {
      this.saveConfiguration({ auto_save_consecutivo: this.autoSaveCheckboxTarget.checked })
    }
  }
}
