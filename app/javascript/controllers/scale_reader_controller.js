import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="scale-reader"
export default class extends Controller {
  static targets = ["progressCircle", "weightDisplay", "scaleStatus", "connectButton", "readButton", "scaleIndicator"]
  static values = { maxWeight: Number }

  connect() {
    console.log("Scale reader controller connected")
    this.isConnected = false
    this.currentWeight = 0.0
    this.maxWeight = this.maxWeightValue || 100
    
    // Configurar el círculo de progreso
    this.circumference = 2 * Math.PI * 56 // radio = 56
    this.progressCircleTarget.style.strokeDasharray = this.circumference
    this.progressCircleTarget.style.strokeDashoffset = this.circumference
    
    // Inicializar estado
    this.updateDisplay(0)
  }

  async connectScale() {
    this.updateStatus("Conectando...", "connecting")
    this.connectButtonTarget.disabled = true
    
    try {
      const response = await this.makeRequest('/admin/manual_printing/connect_scale')
      
      if (response.success) {
        this.isConnected = true
        this.updateStatus("Báscula conectada", "connected")
        this.connectButtonTarget.textContent = "✓ Conectada"
        this.connectButtonTarget.disabled = true
        this.readButtonTarget.disabled = false
        
        // Auto-leer peso cada 3 segundos
        this.startAutoReading()
        
        this.addToLog(`Báscula conectada: ${response.output}`, 'success')
      } else {
        this.updateStatus("Error de conexión", "error")
        this.connectButtonTarget.disabled = false
        this.addToLog(`Error conectando báscula: ${response.error}`, 'error')
      }
    } catch (error) {
      this.updateStatus("Error de conexión", "error")
      this.connectButtonTarget.disabled = false
      this.addToLog(`Error de conexión: ${error.message}`, 'error')
    }
  }

  async readWeight() {
    if (!this.isConnected) {
      this.addToLog("Báscula no conectada", 'warning')
      return
    }
    
    console.log("Reading weight...")
    this.readButtonTarget.disabled = true
    
    try {
      const response = await this.makeRequest('/admin/manual_printing/read_weight')
      
      if (response.success) {
        const weight = parseFloat(response.weight) || 0.0
        this.updateDisplay(weight)
        this.addToLog(`Peso leído: ${weight} kg`, 'success')
      } else {
        this.addToLog(`Error leyendo peso: ${response.error}`, 'error')
        this.updateDisplay(0)
      }
    } catch (error) {
      this.addToLog(`Error leyendo peso: ${error.message}`, 'error')
      this.updateDisplay(0)
    } finally {
      this.readButtonTarget.disabled = false
    }
  }

  startAutoReading() {
    // Leer peso automáticamente cada 3 segundos
    this.autoReadInterval = setInterval(() => {
      if (this.isConnected) {
        this.readWeight()
      }
    }, 3000)
  }

  stopAutoReading() {
    if (this.autoReadInterval) {
      clearInterval(this.autoReadInterval)
      this.autoReadInterval = null
    }
  }

  updateDisplay(weight) {
    this.currentWeight = weight
    
    // Actualizar texto
    this.weightDisplayTarget.textContent = weight.toFixed(1)
    
    // Calcular porcentaje (0-100kg)
    const percentage = Math.min((weight / this.maxWeight) * 100, 100)
    
    // Actualizar círculo de progreso
    const offset = this.circumference - (percentage / 100) * this.circumference
    this.progressCircleTarget.style.strokeDashoffset = offset
    
    // Cambiar color según el peso
    let color = '#059669' // verde por defecto
    if (percentage > 80) {
      color = '#dc2626' // rojo si está cerca del máximo
    } else if (percentage > 60) {
      color = '#f59e0b' // amarillo/naranja
    }
    
    this.progressCircleTarget.style.stroke = color
    
    // Disparar evento personalizado para que otros controladores puedan escuchar
    const weightUpdatedEvent = new CustomEvent('scale:weight-updated', {
      detail: { weight: weight },
      bubbles: true
    })
    document.dispatchEvent(weightUpdatedEvent)
  }

  updateStatus(message, type) {
    this.scaleStatusTarget.textContent = message
    
    // Solo cambiar el color del indicador, mantener el estilo del contenedor
    if (this.hasScaleIndicatorTarget) {
      this.scaleIndicatorTarget.className = "w-3 h-3 rounded-full mr-3"
      
      switch (type) {
        case 'connected':
          this.scaleIndicatorTarget.classList.add('bg-green-500')
          break
        case 'connecting':
          this.scaleIndicatorTarget.classList.add('bg-blue-500')
          break
        case 'error':
          this.scaleIndicatorTarget.classList.add('bg-red-500')
          break
        default:
          this.scaleIndicatorTarget.classList.add('bg-red-500')
      }
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
    logEntry.innerHTML = `[${timestamp}] 📊 ${message}`
    
    activityLog.appendChild(logEntry)
    activityLog.scrollTop = activityLog.scrollHeight
  }

  disconnect() {
    console.log("Scale reader controller disconnected")
    this.stopAutoReading()
  }
}