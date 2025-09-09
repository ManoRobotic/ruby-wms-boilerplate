import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "weight", "portSelect", "connectBtn", "readBtn"]
  static values = { 
    baseUrl: String,
    autoConnect: Boolean,
    savedPort: String
  }

  connect() {
    this.baseUrlValue = this.baseUrlValue || "http://localhost:5002"
    
    // Si autoConnect está activo, intentar conectar automáticamente
    if (this.autoConnectValue) {
      this.checkHealth()
    } else {
      // Solo cargar puertos si no estamos en autoConnect
      this.loadPorts()
    }
    
    // Añadir evento para detectar cambio de puerto
    if (this.hasPortSelectTarget) {
      this.portSelectTarget.addEventListener('change', this.handlePortChange.bind(this))
    }
    
    this.log("Consecutivo scale controller initialized")
  }

  disconnect() {
    // Detener polling si existe
    this.stopPolling()
    
    // Remover event listener
    if (this.hasPortSelectTarget) {
      this.portSelectTarget.removeEventListener('change', this.handlePortChange.bind(this))
    }
  }

  async checkHealth() {
    try {
      const response = await fetch(`${this.baseUrlValue}/health`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        }
      })
      const data = await response.json()
      
      if (data.status === 'healthy') {
        this.updateStatus("✓ Serial server connected", "success")
        await this.loadPorts()
        
        // Si hay un puerto guardado, conectar automáticamente
        if (this.savedPortValue) {
          this.autoConnectScale()
        }
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
      const response = await fetch(`${this.baseUrlValue}/ports`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        }
      })
      const data = await response.json()
      
      if (data.status === 'success' && this.hasPortSelectTarget) {
        // Guardar la selección actual si existe
        const currentSelection = this.portSelectTarget.value
        
        this.portSelectTarget.innerHTML = '<option value="">Select port...</option>'
        data.ports.forEach(port => {
          const option = document.createElement('option')
          option.value = port.device
          option.textContent = `${port.device} - ${port.description}`
          this.portSelectTarget.appendChild(option)
        })
        
        // Select the saved port if available
        if (this.savedPortValue) {
          const savedPortOption = Array.from(this.portSelectTarget.options).find(option => option.value === this.savedPortValue)
          if (savedPortOption) {
            this.portSelectTarget.value = this.savedPortValue
          }
        }
        // Otherwise, restore previous selection if the port is still available
        else if (currentSelection) {
          const portOption = Array.from(this.portSelectTarget.options).find(option => option.value === currentSelection)
          if (portOption) {
            this.portSelectTarget.value = currentSelection
          }
        }
      }
    } catch (error) {
      this.log(`Error loading ports: ${error.message}`)
    }
  }

  async autoConnectScale() {
    // Conectar automáticamente si hay un puerto guardado
    if (this.savedPortValue) {
      const port = this.savedPortValue
      const baudrate = 115200
      
      try {
        this.log(`Attempting to auto-connect to scale on port: ${port}`)
        const response = await fetch(`${this.baseUrlValue}/scale/connect`, {
          method: 'POST',
          headers: { 
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ port, baudrate })
        })
        
        const data = await response.json()
        this.log(`Scale connection response: ${JSON.stringify(data)}`)
        
        if (data.status === 'success') {
          this.updateStatus("✓ Scale connected", "success")
          this.log(`Scale auto-connected on ${port}`)
          
          // Iniciar lectura automática
          this.log("Starting auto reading...")
          await this.startAutoReading()
          this.log("Auto reading started")
          
          // Deshabilitar botón de conectar y ocultar botón de leer
          if (this.hasConnectBtnTarget) {
            this.connectBtnTarget.disabled = true
            this.connectBtnTarget.classList.add('opacity-50', 'cursor-not-allowed')
          }
          if (this.hasReadBtnTarget) {
            this.readBtnTarget.classList.add('hidden')
          }
        } else {
          this.updateStatus("✗ Failed to auto-connect scale", "error")
          this.log(`Auto-connection failed: ${data.message}`)
        }
      } catch (error) {
        this.updateStatus("✗ Auto-connection error", "error")
        this.log(`Error: ${error.message}`)
      }
    }
  }

  async connectScale(event) {
    if (event) event.preventDefault()
    
    const port = this.hasPortSelectTarget ? this.portSelectTarget.value : '/dev/ttyS0'
    const baudrate = 115200
    
    if (!port) {
      this.updateStatus("Please select a port", "error")
      return
    }

    try {
      const response = await fetch(`${this.baseUrlValue}/scale/connect`, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ port, baudrate })
      })
      
      const data = await response.json()
      
      if (data.status === 'success') {
        this.updateStatus("✓ Scale connected", "success")
        this.log(`Scale connected on ${port}`)
        
        // Guardar el puerto en la configuración
        this.saveConfiguration({ serial_port: port })
        
        // Iniciar lectura automática
        await this.startAutoReading()
        
        // Deshabilitar botón de conectar y ocultar botón de leer
        if (this.hasConnectBtnTarget) {
          this.connectBtnTarget.disabled = true
          this.connectBtnTarget.classList.add('opacity-50', 'cursor-not-allowed')
        }
        if (this.hasReadBtnTarget) {
          this.readBtnTarget.classList.add('hidden')
        }
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
    if (event) event.preventDefault()
    
    try {
      const response = await fetch(`${this.baseUrlValue}/scale/disconnect`, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
        }
      })
      
      const data = await response.json()
      
      if (data.status === 'success') {
        this.updateStatus("Scale disconnected", "info")
        this.updateWeight("--", "--")
        this.log("Scale disconnected")
        
        // Habilitar botón de conectar y deshabilitar botón de leer
        if (this.hasConnectBtnTarget) {
          this.connectBtnTarget.disabled = false
          this.connectBtnTarget.classList.remove('opacity-50', 'cursor-not-allowed')
        }
        if (this.hasReadBtnTarget) {
          this.readBtnTarget.disabled = true
          this.readBtnTarget.classList.add('opacity-50', 'cursor-not-allowed')
        }
      }
    } catch (error) {
      this.log(`Error disconnecting: ${error.message}`)
    }
  }

  async readWeightNow(event) {
    if (event) event.preventDefault()
    
    // Mostrar spinner mientras se obtiene la lectura
    this.showSpinner()
    
    try {
      const response = await fetch(`${this.baseUrlValue}/scale/read`, {
        method: 'GET',
        headers: { 
          'Content-Type': 'application/json',
        }
      })
      const data = await response.json()
      
      // Ocultar spinner
      this.hideSpinner()
      
      if (data.status === 'success') {
        this.updateWeight(data.weight, data.timestamp)
        this.log(`Weight read: ${data.weight}`)
      } else {
        this.log("No weight reading available")
      }
    } catch (error) {
      // Ocultar spinner en caso de error
      this.hideSpinner()
      this.log(`Error reading weight: ${error.message}`)
    }
  }

  async startAutoReading() {
    try {
      this.log("Showing spinner for auto reading")
      // Mostrar spinner mientras se inicia la lectura
      this.showSpinner()
      
      this.log("Sending request to start scale reading")
      // Iniciar la lectura continua en el servidor
      const response = await fetch(`${this.baseUrlValue}/scale/start`, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
        }
      })
      
      const data = await response.json()
      this.log(`Scale start response: ${JSON.stringify(data)}`)
      
      if (data.status === 'success') {
        this.log("Started auto reading")
        // Iniciar el polling local para obtener las lecturas
        this.startPolling()
        // Obtener la primera lectura inmediatamente
        this.log("Getting first reading")
        await this.getLatestReadings()
      } else {
        this.log("Failed to start auto reading, hiding spinner")
        // Ocultar spinner si hay error
        this.hideSpinner()
      }
    } catch (error) {
      this.log(`Error starting auto reading: ${error.message}`)
      // Ocultar spinner en caso de error
      this.hideSpinner()
    }
  }

  startPolling() {
    // Iniciar polling para obtener las lecturas cada 1000ms (1 segundo)
    this.pollTimer = setInterval(() => {
      this.getLatestReadings()
    }, 1000)
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer)
      this.pollTimer = null
    }
  }

  async getLatestReadings() {
    try {
      this.log("Fetching latest readings from scale")
      const response = await fetch(`${this.baseUrlValue}/scale/latest`, {
        method: 'GET',
        headers: { 
          'Content-Type': 'application/json',
        }
      })
      const data = await response.json()
      this.log(`Latest readings response: ${JSON.stringify(data)}`)
      
      if (data.status === 'success' && data.readings.length > 0) {
        this.log(`Got ${data.readings.length} readings, processing latest`)
        // Obtener la última lectura
        const latest = data.readings[data.readings.length - 1]
        this.updateWeight(latest.weight, latest.timestamp)
      } else {
        this.log("No readings available or error in response")
      }
    } catch (error) {
      // Silent error to avoid log spam
      this.log(`Error fetching latest readings: ${error.message}`)
    }
  }

  showSpinner() {
    if (this.hasWeightTarget) {
      // Guardar el contenido original
      this.originalWeightContent = this.weightTarget.innerHTML
      
      // Mostrar spinner simplificado
      this.weightTarget.innerHTML = `
        <div class="flex flex-col items-center justify-center py-8">
          <!-- Simple Spinner -->
          <div class="relative">
            <svg class="w-16 h-16 animate-spin text-blue-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
          </div>
          
          <!-- Loading Text -->
          <div class="mt-4 text-center">
            <span class="text-sm text-gray-600 block">Leyendo peso...</span>
          </div>
        </div>
      `;
    }
  }

  hideSpinner() {
    if (this.hasWeightTarget && this.originalWeightContent) {
      this.weightTarget.innerHTML = this.originalWeightContent;
    }
  }

  updateStatus(message, type = "info") {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      // Use Tailwind classes instead of custom CSS
      switch(type) {
        case "success":
          this.statusTarget.className = "px-2 py-1 rounded text-xs font-medium bg-green-100 text-green-800"
          break
        case "error":
          this.statusTarget.className = "px-2 py-1 rounded text-xs font-medium bg-red-100 text-red-800"
          break
        case "info":
        default:
          this.statusTarget.className = "px-2 py-1 rounded text-xs font-medium bg-blue-100 text-blue-800"
          break
      }
    }
  }

  updateWeight(weight, timestamp) {
    if (this.hasWeightTarget) {
      // Convertir el peso a número
      const weightValue = parseFloat(weight) || 0;
      
      // Calcular porcentaje (0-150 kg -> 0-100%)
      const percentage = Math.min(100, Math.max(0, (weightValue / 150) * 100));
      
      // Calcular el stroke-dashoffset para el círculo
      // stroke-dasharray="100", así que offset = 100 - porcentaje
      const strokeOffset = 100 - percentage;
      
      // Determinar el color según el porcentaje
      let colorClass = "text-blue-600";
      if (percentage > 75) {
        colorClass = "text-red-600";
      } else if (percentage > 50) {
        colorClass = "text-yellow-500";
      }
      
      this.weightTarget.innerHTML = `
        <div class="flex flex-col items-center justify-center">
          <!-- Circular Progress -->
          <div class="relative size-40">
            <svg class="size-full -rotate-90" viewBox="0 0 36 36" xmlns="http://www.w3.org/2000/svg">
              <!-- Background Circle -->
              <circle cx="18" cy="18" r="16" fill="none" class="stroke-current text-gray-200" stroke-width="2"></circle>
              <!-- Progress Circle -->
              <circle cx="18" cy="18" r="16" fill="none" class="stroke-current ${colorClass}" stroke-width="2" stroke-dasharray="100" stroke-dashoffset="${strokeOffset}" stroke-linecap="round"></circle>
            </svg>
            
            <!-- Percentage Text -->
            <div class="absolute top-1/2 start-1/2 transform -translate-y-1/2 -translate-x-1/2">
              <span class="text-center text-2xl font-bold ${colorClass}">${weightValue.toFixed(1)}</span>
            </div>
          </div>
          
          <!-- Weight Label -->
          <div class="mt-2 text-center">
            <span class="text-sm text-gray-500 block">kg</span>
            <span class="text-xs text-gray-400 block">${timestamp}</span>
          </div>
        </div>
      `;
      
      // Ocultar spinner si estaba visible
      if (this.originalWeightContent) {
        delete this.originalWeightContent;
      }
      
      // Asignar automáticamente el peso al campo de peso bruto del formulario
      this.assignWeightToForm(weightValue);
      
      // Disparar evento personalizado para notificar que el peso ha sido actualizado
      this.dispatch('weightUpdated', {
        detail: { weight: weightValue, timestamp: timestamp }
      });
      
      // También disparar el evento antiguo para mantener compatibilidad
      this.element.dispatchEvent(new CustomEvent('serial:weightRead', {
        detail: { weight: weightValue, timestamp: timestamp },
        bubbles: true
      }));
    }
  }

  // Asignar el peso al campo de peso bruto del formulario
  assignWeightToForm(weight) {
    // Buscar el campo de peso bruto en el formulario padre
    const form = this.element.closest('form');
    if (form) {
      const pesoBrutoInput = form.querySelector('[data-consecutivo-form-target="pesoBrutoInput"]');
      if (pesoBrutoInput) {
        // Asignar el valor
        pesoBrutoInput.value = weight.toFixed(2);
        
        // Disparar el evento input para que se actualicen los cálculos
        pesoBrutoInput.dispatchEvent(new Event('input', { bubbles: true }));
      }
      
      // También actualizar el campo hidden de peso bruto
      const pesoBrutoHidden = form.querySelector('[data-consecutivo-form-target="pesoBrutoHidden"]');
      if (pesoBrutoHidden) {
        pesoBrutoHidden.value = weight.toFixed(2);
      }
    }
  }

  log(message) {
    const timestamp = new Date().toLocaleTimeString()
    const logMessage = `[${timestamp}] ${message}`
    
    console.log(logMessage)
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

  // Manejar cambio de puerto serial
  handlePortChange(event) {
    this.log(`Port changed to: ${event.target.value}`)
    
    // Detener cualquier lectura automática en curso
    this.stopAutoReading()
    
    // Resetear estado de los botones
    if (this.hasConnectBtnTarget) {
      this.connectBtnTarget.disabled = false
      this.connectBtnTarget.classList.remove('opacity-50', 'cursor-not-allowed')
    }
    
    if (this.hasReadBtnTarget) {
      this.readBtnTarget.disabled = false
      this.readBtnTarget.classList.remove('opacity-50', 'cursor-not-allowed', 'hidden')
    }
    
    // Resetear estado de conexión
    this.updateStatus("Seleccione puerto y haga clic en Conectar", "info")
    
    // Si había contenido original guardado, restaurarlo
    if (this.originalWeightContent) {
      if (this.hasWeightTarget) {
        this.weightTarget.innerHTML = this.originalWeightContent
      }
      delete this.originalWeightContent
    } else {
      // Resetear display de peso
      if (this.hasWeightTarget) {
        this.weightTarget.innerHTML = `
          <div class="text-xl font-bold block text-center transition-all duration-300 ease-in-out text-gray-400">--</div>
          <div class="text-xs text-gray-500 block text-center">--</div>
        `
      }
    }
  }

  // Detener lectura automática
  async stopAutoReading() {
    try {
      this.log("Stopping auto reading")
      
      // Detener polling local
      this.stopPolling()
      
      // Detener lectura en el servidor
      const response = await fetch(`${this.baseUrlValue}/scale/stop`, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
        }
      })
      
      const data = await response.json()
      if (data.status === 'success') {
        this.log("Auto reading stopped successfully")
      } else {
        this.log("Failed to stop auto reading")
      }
    } catch (error) {
      this.log(`Error stopping auto reading: ${error.message}`)
    }
  }
}