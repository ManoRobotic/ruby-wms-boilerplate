import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "weight", "readBtn", "autoSaveCheckbox"]
  static values = { 
    baseUrl: String,
    savedPort: String,
    autoSave: Boolean
  }

  connect() {
    this.baseUrlValue = this.baseUrlValue || "http://localhost:5000"
    this.isReading = false
    
    // Si hay un puerto guardado, iniciar la lectura automática inmediatamente
    if (this.savedPortValue) {
      this.startAutoReading()
    } else {
      this.checkServerConnection()
    }

    if (this.hasAutoSaveCheckboxTarget) {
      this.autoSaveCheckboxTarget.checked = this.autoSaveValue
    }
    
    // Escuchar eventos de apertura y cierre del modal
    document.addEventListener('modal:open', this.handleModalOpen.bind(this))
    document.addEventListener('modal:close', this.handleModalClose.bind(this))
  }

  disconnect() {
    // Detener la lectura automática al desconectar
    this.stopAutoReading()
    
    // Remover event listeners
    document.removeEventListener('modal:open', this.handleModalOpen.bind(this))
    document.removeEventListener('modal:close', this.handleModalClose.bind(this))
  }

  handleModalOpen() {
    // Iniciar lectura automática cuando se abre el modal
    if (this.savedPortValue && this.portSelectTarget.value === this.savedPortValue) {
      this.startAutoReading()
    }
  }

  handleModalClose() {
    // Detener la lectura automática cuando se cierra el modal
    this.stopAutoReading()
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

  async startAutoReading() {
    console.log("startAutoReading called");
    if (this.isReading) {
      console.log("Already reading, returning");
      return
    }
    
    const port = this.savedPortValue
    console.log("Using saved port:", port);
    if (!port) {
      this.updateStatus("No saved port configuration", "error")
      return
    }
    
    this.isReading = true
    // Mostrar spinner inmediatamente al iniciar la lectura automática
    this.showSpinner()
    this.updateStatus("Letendo datos de la bascula...", "info")
    
    try {
      // Conectar con la báscula
      const baudrate = 115200
      console.log("Connecting to scale at port:", port);
      const response = await fetch(`${this.baseUrlValue}/scale/connect`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'skip_zrok_interstitial': 'true'
        },
        body: JSON.stringify({ port, baudrate })
      })
      const data = await response.json()
      console.log("Scale connection response:", data);
      
      if (data.status !== 'success') {
        throw new Error('Failed to connect to scale')
      }
      
      this.updateStatus("Connected, waiting for weight...", "success")
      
      // Iniciar lectura continua
      console.log("Starting continuous reading");
      await fetch(`${this.baseUrlValue}/scale/start`, {
        method: 'POST',
        headers: {
          'skip_zrok_interstitial': 'true'
        }
      })
      
      // Iniciar polling para obtener lecturas
      console.log("Starting polling");
      this.startPolling()
    } catch (error) {
      console.error("Error in startAutoReading:", error);
      this.updateStatus(`Error: ${error.message}`, "error")
      this.isReading = false
    }
  }

  startPolling() {
    if (!this.isReading) return
    
    console.log("Starting polling for weight readings...");
    this.pollingInterval = setInterval(async () => {
      try {
        console.log("Polling for latest weight reading...");
        const response = await fetch(`${this.baseUrlValue}/scale/latest`, {
          headers: {
            'skip_zrok_interstitial': 'true'
          }
        })
        const data = await response.json()
        console.log("Received weight data:", data);
        
        if (data.status === 'success' && data.readings.length > 0) {
          const latest = data.readings[data.readings.length - 1]
          console.log("Updating weight with:", latest.weight, latest.timestamp);
          this.updateWeight(latest.weight, latest.timestamp)
        }
      } catch (error) {
        console.error("Error polling for weight:", error);
        // Silenciar errores de polling para evitar spam en logs
      }
    }, 1000) // Poll cada segundo
  }

  stopAutoReading() {
    if (!this.isReading) return
    
    this.isReading = false
    
    // Detener polling
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval)
      this.pollingInterval = null
    }
    
    // Detener lectura en el servidor
    fetch(`${this.baseUrlValue}/scale/stop`, {
      method: 'POST',
      headers: {
        'skip_zrok_interstitial': 'true'
      }
    }).catch(() => {
      // Silenciar errores al detener
    })
    
    // Desconectar la báscula
    fetch(`${this.baseUrlValue}/scale/disconnect`, {
      method: 'POST',
      headers: {
        'skip_zrok_interstitial': 'true'
      }
    }).catch(() => {
      // Silenciar errores al desconectar
    })
    
    this.updateStatus("Auto reading stopped", "info")
  }

  async getWeight(event) {
    if (event) event.preventDefault()

    const port = this.savedPortValue
    if (!port) {
      this.updateStatus("No saved port configuration", "error")
      return
    }

    this.showSpinner()
    this.readBtnTarget.disabled = true

    try {
      // Conectar con la báscula
      const baudrate = 115200
      let response = await fetch(`${this.baseUrlValue}/scale/connect`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'skip_zrok_interstitial': 'true'
        },
        body: JSON.stringify({ port, baudrate })
      })
      let data = await response.json()
      if (data.status !== 'success') {
        throw new Error('Failed to connect to scale')
      }

      // Leer el peso
      response = await fetch(`${this.baseUrlValue}/scale/read`, {
        headers: {
          'skip_zrok_interstitial': 'true'
        }
      })
      data = await response.json()
      if (data.status !== 'success') {
        throw new Error('Failed to read from scale')
      }

      this.hideSpinner()
      this.updateWeight(data.weight, data.timestamp)
      this.updateStatus("Weight read successfully", "success")

      // Desconectar la báscula
      await fetch(`${this.baseUrlValue}/scale/disconnect`, { method: 'POST' })
    } catch (error) {
      this.hideSpinner()
      this.updateStatus(`Error: ${error.message}`, "error")
    } finally {
      this.readBtnTarget.disabled = false
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
    console.log("updateWeight called with:", weight, timestamp);
    if (this.hasWeightTarget) {
      const weightValue = parseFloat(weight) || 0
      console.log("Processed weight value:", weightValue);
      const percentage = Math.min(100, Math.max(0, weightValue))
      const strokeOffset = 100 - percentage
      
      let colorClass = "text-blue-600"
      if (percentage > 75) {
        colorClass = "text-red-600"
      } else if (percentage > 50) {
        colorClass = "text-yellow-500"
      }

      // Crear el contenido HTML para el peso
      const weightHTML = `
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
      
      console.log("Updating weight target with HTML");
      // Actualizar el contenido del target de peso
      this.weightTarget.innerHTML = weightHTML
      
      // Dispatch event to notify the form controller
      console.log("Dispatching serial:weightRead event");
      this.element.dispatchEvent(new CustomEvent('serial:weightRead', {
        detail: { weight: weightValue, timestamp: timestamp },
        bubbles: true
      }));

      // Registrar automáticamente el peso en el formulario
      console.log("Registering weight in form");
      this.registerWeightInForm(weightValue);

      if (this.hasAutoSaveCheckboxTarget && this.autoSaveCheckboxTarget.checked) {
        console.log("Auto-save enabled, submitting form");
        this.element.closest('form').requestSubmit()
      }
    } else {
      console.log("No weight target found");
    }
  }

  // Método para registrar automáticamente el peso en el formulario
  registerWeightInForm(weightValue) {
    // Encontrar el formulario padre
    const form = this.element.closest('form');
    if (!form) return;
    
    // Encontrar el campo oculto de peso bruto
    const pesoBrutoInput = form.querySelector('input[name*="[peso_bruto]"]');
    if (pesoBrutoInput) {
      pesoBrutoInput.value = weightValue;
    }
    
    // También actualizar el campo de peso bruto manual si existe
    const pesoBrutoManualInput = form.querySelector('input[name*="[peso_bruto_manual]"]');
    if (pesoBrutoManualInput) {
      pesoBrutoManualInput.value = weightValue;
    }
    
    // Actualizar el peso bruto oculto
    const pesoBrutoHidden = form.querySelector('input[data-consecutivo-form-target="pesoBrutoHidden"]');
    if (pesoBrutoHidden) {
      pesoBrutoHidden.value = weightValue;
    }
    
    // Actualizar también el campo de peso bruto manual oculto si existe
    const pesoBrutoManualHidden = form.querySelector('input[data-consecutivo-form-target="pesoBrutoManualHidden"]');
    if (pesoBrutoManualHidden) {
      pesoBrutoManualHidden.value = weightValue;
    }
    
    // Forzar la actualización de los cálculos directamente
    this.updateFormCalculations(weightValue);
  }
  
  // Método para actualizar directamente los cálculos en el formulario
  updateFormCalculations(weightValue) {
    // Encontrar el formulario padre
    const form = this.element.closest('form');
    if (!form) return;
    
    // Extraer micras y ancho mm desde clave producto (ej: "BOPPTRANS 35 / 420")
    const claveProducto = form.querySelector('#clave_producto')?.value || "BOPPTRANS 35 / 420";
    const matches = claveProducto.match(/(\d+)\s*\/\s*(\d+)/);
    const micras = matches ? parseInt(matches[1]) || 35 : 35;
    const anchoMm = matches ? parseInt(matches[2]) || 420 : 420;
    
    // Tabla de pesos core
    const coreWeightTable = {
      0: 0, 70: 200, 80: 200, 90: 200, 100: 200, 110: 200, 120: 200, 
      124: 200, 130: 200, 140: 200, 142: 200, 143: 200, 150: 200, 
      160: 200, 170: 200, 180: 200, 190: 400, 200: 400, 210: 400, 
      220: 400, 230: 400, 240: 500, 250: 500, 260: 500, 270: 500, 
      280: 500, 290: 600, 300: 600, 310: 600, 320: 600, 330: 600, 
      340: 700, 350: 700, 360: 700, 370: 700, 380: 700, 390: 700, 
      400: 800, 410: 800, 420: 800, 430: 800, 440: 900, 450: 900, 
      460: 900, 470: 900, 480: 900, 490: 1000, 500: 1000, 510: 1000, 
      520: 1000, 530: 1000, 540: 1100, 550: 1100, 560: 1100, 570: 1100, 
      580: 1100, 590: 1200, 600: 1200, 610: 1200, 620: 1200, 630: 1200, 
      640: 1300, 650: 1300, 660: 1300, 670: 1300, 680: 1300, 690: 1400, 
      700: 1400, 710: 1400, 720: 1400, 730: 1400, 740: 1500, 750: 1500, 
      760: 1500, 770: 1500, 780: 1500, 790: 1600, 800: 1600, 810: 1600, 
      820: 1600, 830: 1600, 840: 1700, 850: 1700, 860: 1700, 870: 1700, 
      880: 1700, 890: 1800, 900: 1800, 910: 1800, 920: 1800, 930: 1800, 
      940: 1900, 950: 1900, 960: 1900, 970: 1900, 980: 1900, 990: 2000, 
      1000: 2000, 1020: 2000, 1040: 1200, 1050: 1200, 1060: 1200, 
      1100: 2200, 1120: 2200, 1140: 2300, 1160: 2300, 1180: 2400, 
      1200: 2400, 1220: 2400, 1240: 2500, 1250: 2500, 1260: 2600, 
      1300: 2600, 1320: 2600, 1340: 2700, 1360: 2700, 1400: 2800
    };
    
    // Encontrar el peso core más cercano
    const alturaCm = 75; // Valor por defecto
    const keys = Object.keys(coreWeightTable).map(k => parseInt(k)).sort((a, b) => a - b);
    let pesoCoreGramos = coreWeightTable[keys[0]];
    for (let i = 0; i < keys.length - 1; i++) {
      if (alturaCm >= keys[i] && alturaCm < keys[i + 1]) {
        pesoCoreGramos = coreWeightTable[keys[i]];
        break;
      }
    }
    
    // Calcular peso neto
    let pesoNeto = weightValue - (pesoCoreGramos / 1000.0);
    pesoNeto = Math.max(0, pesoNeto);
    
    // Calcular metros lineales
    let metrosLineales = 0;
    if (pesoNeto > 0 && micras > 0 && anchoMm > 0) {
      metrosLineales = (pesoNeto * 1000000) / micras / anchoMm / 0.92;
      metrosLineales = Math.max(0, metrosLineales);
    }
    
    // Actualizar displays visuales
    const pesoNetoDisplay = form.querySelector('[data-consecutivo-form-target="pesoNetoDisplay"]');
    if (pesoNetoDisplay) {
      pesoNetoDisplay.textContent = `${pesoNeto.toFixed(3)} kg`;
    }
    
    const metrosLinealesDisplay = form.querySelector('[data-consecutivo-form-target="metrosLinealesDisplay"]');
    if (metrosLinealesDisplay) {
      metrosLinealesDisplay.textContent = `${metrosLineales.toFixed(4)} m`;
    }
    
    const pesoCoreDisplay = form.querySelector('[data-consecutivo-form-target="pesoCoreDisplay"]');
    if (pesoCoreDisplay) {
      pesoCoreDisplay.textContent = `${pesoCoreGramos} g`;
    }
    
    const especificacionesDisplay = form.querySelector('[data-consecutivo-form-target="especificacionesDisplay"]');
    if (especificacionesDisplay) {
      especificacionesDisplay.textContent = `${micras}μ / ${anchoMm}mm`;
    }
    
    // Actualizar campos hidden para formulario
    const pesoNetoHidden = form.querySelector('input[data-consecutivo-form-target="pesoNeto"]');
    if (pesoNetoHidden) {
      pesoNetoHidden.value = pesoNeto.toFixed(3);
    }
    
    const metrosLinealesHidden = form.querySelector('input[data-consecutivo-form-target="metrosLineales"]');
    if (metrosLinealesHidden) {
      metrosLinealesHidden.value = metrosLineales.toFixed(4);
    }
  }
  
  // Método para forzar el cálculo de pesos en el controlador del formulario
  forceFormCalculation(weightValue) {
    // Encontrar el controlador del formulario
    const formControllerElement = this.element.closest('[data-controller="consecutivo-form"]');
    if (formControllerElement && formControllerElement.__controllerInstance) {
      // Acceder directamente a la instancia del controlador
      const formController = formControllerElement.__controllerInstance;
      if (formController) {
        // Actualizar el peso actual y recalcular
        formController.currentWeight = weightValue;
        formController.calculateWeights();
      }
    } else {
      // Fallback: Disparar un evento personalizado
      const event = new CustomEvent('scale:weightUpdated', {
        detail: { weight: weightValue },
        bubbles: true
      });
      this.element.dispatchEvent(event);
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
