import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "weight", "autoSaveCheckbox", "portSelect"]
  static values = { 
    baseUrl: String,
    savedPort: String,
    autoSave: Boolean
  }

  connect() {
    // ALWAYS use the Rails API proxy to avoid CORS/Mixed Content issues and zrok interstitials
    this.baseUrlValue = "/api/serial"
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
    // Resetear estado visual y valores previos
    this.resetState()
    
    // Iniciar lectura automática cuando se abre el modal
    if (this.savedPortValue && this.hasPortSelectTarget && this.portSelectTarget.value === this.savedPortValue) {
      this.startAutoReading()
    }
  }

  resetState() {
    if (this.hasWeightTarget) {
      this.weightTarget.innerHTML = `
        <div class="text-xl font-bold block text-center transition-all duration-300 ease-in-out text-[var(--color-blue-gem-400)]">--</div>
        <div class="text-xs text-[var(--color-blue-gem-500)] block text-center">--</div>
      `
    }
    this.updateStatus("Iniciando...", "info")
    this.registerWeightInForm(0)
  }

  handleModalClose() {
    // Detener la lectura automática cuando se cierra el modal
    this.stopAutoReading()
  }

  async checkServerConnection() {
    try {
      // Usar endpoint de health del proxy
      const healthUrl = `${this.baseUrlValue}/health`
      const response = await fetch(healthUrl)
      
      if (response.ok) {
        const data = await response.json()
        if (data.status === 'healthy') {
          this.updateStatus("Servidor serial conectado", "success")
          return true
        }
      }
      this.updateStatus("Servidor serial desconectado", "error")
      return false
    } catch (error) {
      this.updateStatus("Error de conexión", "error")
      return false
    }
  }

  async loadPorts() {
    this.updateStatus("Cargando puertos...", "info")
    try {
      const response = await fetch(`${this.baseUrlValue}/ports`)
      const data = await response.json()
      
      if (data.status === 'success' && this.hasPortSelectTarget) {
        this.portSelectTarget.innerHTML = '<option value="">Seleccionar puerto...</option>'
        data.ports.forEach(port => {
          const option = document.createElement('option')
          option.value = port.device
          option.textContent = `${port.device} - ${port.description || 'Dispositivo serial'}`
          this.portSelectTarget.appendChild(option)
        })
        
        if (this.savedPortValue) {
          this.portSelectTarget.value = this.savedPortValue
        }
        this.updateStatus("Puertos cargados", "success")
      }
    } catch (error) {
      this.updateStatus("Error cargando puertos: " + error.message, "error")
    }
  }

  async startAutoReading() {
    console.log("startAutoReading called");
    if (this.isReading) return
    
    const port = this.savedPortValue
    if (!port) {
      this.updateStatus("Sin configuración de puerto", "error")
      return
    }
    
    this.isReading = true
    this.showSpinner()
    this.updateStatus("Conectando báscula...", "info")
    
    try {
      // Conectar con la báscula a través del proxy
      const baudrate = 115200
      const response = await fetch(`${this.baseUrlValue}/connect_scale`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({ port, baudrate })
      })
      const data = await response.json()
      
      if (data.status !== 'success') {
        throw new Error(data.message || 'Error conectando báscula')
      }
      
      this.updateStatus("Conectado, iniciando lectura...", "success")
      
      // Iniciar lectura continua
      await fetch(`${this.baseUrlValue}/start_scale`, {
        method: 'POST',
        headers: { 'X-CSRF-Token': this.getCSRFToken() }
      })
      
      // Iniciar polling
      this.startPolling()
    } catch (error) {
      console.error("Error in startAutoReading:", error);
      this.updateStatus(`Error: ${error.message}`, "error")
      this.isReading = false
      this.hideSpinner()
    }
  }

  startPolling() {
    if (!this.isReading) return
    
    this.pollingInterval = setInterval(async () => {
      try {
        const response = await fetch(`${this.baseUrlValue}/latest_readings`)
        const data = await response.json()
        
        if (data.status === 'success' && data.readings.length > 0) {
          const latest = data.readings[data.readings.length - 1]
          
          // Verificar si la lectura es reciente (menos de 5 segundos)
          // El timestamp viene del servidor, asumimos sincronización razonable o usamos tiempo relativo si es posible
          // Si el timestamp es muy viejo, ignoramos para no mostrar datos "pegados"
          if (this.isReadingFresh(latest.timestamp)) {
             this.updateWeight(latest.weight, latest.timestamp)
          } else {
             // Opcional: Mostrar indicador de "Esperando datos frescos..." si solo llegan datos viejos
             // Por ahora mantenemos el estado de carga o el último válido si no es muy viejo
          }
        }
      } catch (error) {
        // Silenciar errores de polling momentáneos
      }
    }, 1000)
  }

  isReadingFresh(timestamp) {
    if (!timestamp) return false
    
    // Intentar parsear el timestamp
    const readingTime = new Date(timestamp).getTime()
    const now = new Date().getTime()
    
    // Si la lectura tiene más de 5 segundos de antigüedad, es "viejas"
    // (Ajustar este umbral según la latencia real de la red/servidor)
    const diff = now - readingTime
    
    // Aceptamos lecturas hasta 10 segundos atrás para ser permisivos con relojes desincronizados,
    // pero descartamos datos de sesiones muy anteriores.
    return diff < 10000 
  }

  stopAutoReading() {
    if (!this.isReading) return
    
    this.isReading = false
    
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval)
      this.pollingInterval = null
    }
    
    // Detener lectura y desconectar
    const stopUrl = `${this.baseUrlValue}/stop_scale`
    const disconnectUrl = `${this.baseUrlValue}/disconnect_scale`
    const headers = { 'X-CSRF-Token': this.getCSRFToken() }

    fetch(stopUrl, { method: 'POST', headers }).catch(() => {})
    fetch(disconnectUrl, { method: 'POST', headers }).catch(() => {})
    
    this.updateStatus("Lectura detenida", "info")
    this.hideSpinner()
  }

  async getWeight(event) {
    if (event) event.preventDefault()

    const port = this.savedPortValue
    if (!port) {
      this.updateStatus("Puerto no configurado", "error")
      return
    }

    this.showSpinner()
    // if (this.hasReadBtnTarget) this.readBtnTarget.disabled = true

    try {
      // 1. Conectar (idempotente en el backend usualmente, pero aseguramos)
      const baudrate = 115200
      let response = await fetch(`${this.baseUrlValue}/connect_scale`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({ port, baudrate })
      })
        
        // Si ya está conectada puede fallar o retornar success, continuamos intentando leer
        
      // 2. Intentar leer con timeout usando get_weight_now
      // timeout de 5 segundos
      response = await fetch(`${this.baseUrlValue}/get_weight_now?timeout=5`)
      const data = await response.json()
      
      if (data.status === 'success') {
        this.updateWeight(data.weight, data.timestamp)
        this.updateStatus("Peso leído exitosamente", "success")
      } else {
        throw new Error(data.message || 'Fallo al leer peso')
      }

    } catch (error) {
      this.updateStatus(`Error al leer: ${error.message}`, "error")
    } finally {
      this.hideSpinner()
      if (this.hasReadBtnTarget) this.readBtnTarget.disabled = false
    }
  }

  showSpinner() {
    if (this.hasWeightTarget) {
      // Guardar contenido original solo si no es el spinner
      if (!this.weightTarget.innerHTML.includes('animate-spin')) {
          this.originalWeightContent = this.weightTarget.innerHTML
      }
      
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
        // Solo restaurar si tenemos contenido válido (no "Reading..." loop)
        // Pero mejor aún, si ya tenemos un peso mostrado por updateWeight, no hacemos nada
        // Si seguimos mostrando el spinner, restauramos el original
        if (this.weightTarget.innerHTML.includes('animate-spin')) {
            this.weightTarget.innerHTML = this.originalWeightContent
        }
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
      
      if (message.includes("conectad") || type === 'success') {
        this.statusTarget.className = `${baseClasses} ${colorClasses.success}`
      } else if (message.includes("Error") || type === 'error') {
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
      if (percentage > 75) colorClass = "text-red-600"
      else if (percentage > 50) colorClass = "text-yellow-500"

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
            <span class="text-xs text-gray-400 block">${timestamp || new Date().toLocaleTimeString()}</span>
          </div>
        </div>
      `
      
      this.weightTarget.innerHTML = weightHTML
      
      this.element.dispatchEvent(new CustomEvent('serial:weightRead', {
        detail: { weight: weightValue, timestamp: timestamp },
        bubbles: true
      }));

      this.registerWeightInForm(weightValue);

      if (this.hasAutoSaveCheckboxTarget && this.autoSaveCheckboxTarget.checked) {
        this.element.closest('form').requestSubmit()
      }
    }
  }

  registerWeightInForm(weightValue) {
    const form = this.element.closest('form');
    if (!form) return;
    
    const pesoBrutoInput = form.querySelector('input[name*="[peso_bruto]"]');
    if (pesoBrutoInput) pesoBrutoInput.value = weightValue;
    
    const pesoBrutoManualInput = form.querySelector('input[name*="[peso_bruto_manual]"]');
    if (pesoBrutoManualInput) pesoBrutoManualInput.value = weightValue;
    
    const pesoBrutoHidden = form.querySelector('input[data-consecutivo-form-target="pesoBrutoHidden"]');
    if (pesoBrutoHidden) pesoBrutoHidden.value = weightValue;
    
    const pesoBrutoManualHidden = form.querySelector('input[data-consecutivo-form-target="pesoBrutoManualHidden"]');
    if (pesoBrutoManualHidden) pesoBrutoManualHidden.value = weightValue;
    
    this.updateFormCalculations(weightValue);
  }
  
  updateFormCalculations(weightValue) {
    const form = this.element.closest('form');
    if (!form) return;
    
    const claveProducto = form.querySelector('#clave_producto')?.value || "BOPPTRANS 35 / 420";
    const matches = claveProducto.match(/(\d+)\s*\/\s*(\d+)/);
    const micras = matches ? parseInt(matches[1]) || 35 : 35;
    const anchoMm = matches ? parseInt(matches[2]) || 420 : 420;
    
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
    
    const alturaCm = 75;
    const keys = Object.keys(coreWeightTable).map(k => parseInt(k)).sort((a, b) => a - b);
    let pesoCoreGramos = coreWeightTable[keys[0]];
    for (let i = 0; i < keys.length - 1; i++) {
      if (alturaCm >= keys[i] && alturaCm < keys[i + 1]) {
        pesoCoreGramos = coreWeightTable[keys[i]];
        break;
      }
    }
    
    let pesoNeto = weightValue - (pesoCoreGramos / 1000.0);
    pesoNeto = Math.max(0, pesoNeto);
    
    let metrosLineales = 0;
    if (pesoNeto > 0 && micras > 0 && anchoMm > 0) {
      metrosLineales = (pesoNeto * 1000000) / micras / anchoMm / 0.92;
      metrosLineales = Math.max(0, metrosLineales);
    }
    
    const pesoNetoDisplay = form.querySelector('[data-consecutivo-form-target="pesoNetoDisplay"]');
    if (pesoNetoDisplay) pesoNetoDisplay.textContent = `${pesoNeto.toFixed(3)} kg`;
    
    const metrosLinealesDisplay = form.querySelector('[data-consecutivo-form-target="metrosLinealesDisplay"]');
    if (metrosLinealesDisplay) metrosLinealesDisplay.textContent = `${metrosLineales.toFixed(4)} m`;
    
    const pesoCoreDisplay = form.querySelector('[data-consecutivo-form-target="pesoCoreDisplay"]');
    if (pesoCoreDisplay) pesoCoreDisplay.textContent = `${pesoCoreGramos} g`;
    
    const especificacionesDisplay = form.querySelector('[data-consecutivo-form-target="especificacionesDisplay"]');
    if (especificacionesDisplay) especificacionesDisplay.textContent = `${micras}μ / ${anchoMm}mm`;
    
    const pesoNetoHidden = form.querySelector('input[data-consecutivo-form-target="pesoNeto"]');
    if (pesoNetoHidden) pesoNetoHidden.value = pesoNeto.toFixed(3);
    
    const metrosLinealesHidden = form.querySelector('input[data-consecutivo-form-target="metrosLineales"]');
    if (metrosLinealesHidden) metrosLinealesHidden.value = metrosLineales.toFixed(4);
  }

  saveConfiguration(configData) {
    fetch('/admin/configurations/auto_save', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken()
      },
      body: JSON.stringify(configData)
    })
    .then(response => response.json())
    .catch(error => {
      console.error(`Error saving configuration: ${error.message}`)
    })
  }

  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }

  saveAutoSaveState() {
    if (this.hasAutoSaveCheckboxTarget) {
      this.saveConfiguration({ auto_save_consecutivo: this.autoSaveCheckboxTarget.checked })
    }
  }
}
