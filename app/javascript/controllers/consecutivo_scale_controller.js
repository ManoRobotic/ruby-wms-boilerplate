import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["weight", "status"]

  connect() {
    this.log("Conectado y escuchando eventos de peso y estado.")
    this.isWeightReceived = false
    this.boundHandleWeightUpdate = this.handleWeightUpdate.bind(this)
    this.boundHandleStatusUpdate = this.handleStatusUpdate.bind(this)
    
    document.addEventListener("serial:weight-update", this.boundHandleWeightUpdate)
    document.addEventListener("serial:status-update", this.boundHandleStatusUpdate)

    // Solicitar estado actual inmediatamente
    this.requestCurrentStatus();
  }

  requestCurrentStatus() {
    // this.log("Solicitando estado actual de la serie...");
    this.dispatch("request-status", { prefix: "serial", bubbles: true });
    this.dispatch("request-status", { bubbles: true }); // Keep old one just in case
  }

  disconnect() {
    this.log("Desconectado, dejando de escuchar eventos.")
    document.removeEventListener("serial:weight-update", this.boundHandleWeightUpdate)
    document.removeEventListener("serial:status-update", this.boundHandleStatusUpdate)
  }

  handleStatusUpdate(event) {
    const { scale_connected, scale_port } = event.detail
    // console.log(`[Scale] Estado: ${scale_connected ? 'Conectado' : 'Desconectado'} en ${scale_port}`)
    this.updateStatusUI(scale_connected, scale_port)
  }

  updateStatusUI(connected, port) {
    if (this.hasStatusTarget) {
      if (connected) {
        this.statusTarget.textContent = `Conectada en ${port}`
        this.statusTarget.className = "px-2 py-1 rounded text-xs font-medium bg-green-100 text-green-800"
        
        // Si está conectada pero aún no recibimos peso, mostrar spinner
        if (!this.isWeightReceived && this.hasWeightTarget) {
          this.showWaitingSpinner()
        }
      } else {
        this.statusTarget.textContent = "Desconectada"
        this.statusTarget.className = "px-2 py-1 rounded text-xs font-medium bg-red-100 text-red-800"
        this.isWeightReceived = false // Resetear al desconectar
      }
    }
  }

  showWaitingSpinner() {
    this.weightTarget.innerHTML = `
      <div class="flex flex-col items-center justify-center py-2">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mb-2"></div>
        <div class="text-xs text-blue-600 font-medium animate-pulse">Esperando peso...</div>
      </div>
    `
  }

  handleWeightUpdate(event) {
    const { weight, timestamp } = event.detail
    this.isWeightReceived = true
    console.log(`[Scale] ⚖️ Peso recibido del bus: ${weight}`)
    this.updateWeightUI(weight, timestamp)
  }

  /**
   * Actualiza la interfaz de usuario con el nuevo peso y realiza los cálculos.
   * Esta lógica se mantiene de la versión anterior.
   */
  updateWeightUI(weight, timestamp) {
    if (this.hasWeightTarget) {
      const weightValue = parseFloat(weight) || 0
      
      const weightHTML = `
        <div class="flex flex-col items-center justify-center">
          <div class="text-center">
            <span class="text-4xl font-bold text-blue-600">${weightValue.toFixed(2)}</span>
            <span class="text-lg text-gray-500">kg</span>
          </div>
          <div class="mt-1 text-center">
            <span class="text-xs text-gray-400">${new Date(timestamp).toLocaleTimeString()}</span>
          </div>
        </div>
      `
      this.weightTarget.innerHTML = weightHTML
      
      // Llama a la lógica para actualizar los campos del formulario.
      this.updateFormCalculations(weightValue)
    }
  }

  /**
   * Rellena los campos del formulario con el peso y los valores calculados.
   * Esta lógica se mantiene de la versión anterior.
   */
  updateFormCalculations(weightValue) {
    const form = this.element.closest('form')
    if (!form) return

    // Actualizar campos de peso bruto
    const pesoBrutoInput = form.querySelector('input[name*="[peso_bruto]"]')
    if (pesoBrutoInput) pesoBrutoInput.value = weightValue.toFixed(3)

    // ... (El resto de la lógica de cálculo se mantiene) ...
    
    // Suponemos que los valores para el cálculo están disponibles en el formulario
    const claveProducto = form.querySelector('#clave_producto')?.value || "BOPPTRANS 35 / 420";
    const matches = claveProducto.match(/(\d+)\s*\/\s*(\d+)/);
    const micras = matches ? parseInt(matches[1]) || 35 : 35;
    const anchoMm = matches ? parseInt(matches[2]) || 420 : 420;

    const coreWeightTable = {
      420: 800, 1000: 2000, 1400: 2800 // Tabla simplificada
    };
    const pesoCoreGramos = coreWeightTable[anchoMm] || 800; // Default

    let pesoNeto = weightValue - (pesoCoreGramos / 1000.0)
    pesoNeto = Math.max(0, pesoNeto)

    let metrosLineales = 0
    if (pesoNeto > 0 && micras > 0 && anchoMm > 0) {
      metrosLineales = (pesoNeto * 1000000) / micras / anchoMm / 0.92
    }

    // Actualizar campos de peso neto y metros
    const pesoNetoDisplay = form.querySelector('[data-consecutivo-form-target="pesoNetoDisplay"]')
    if (pesoNetoDisplay) pesoNetoDisplay.textContent = `${pesoNeto.toFixed(3)} kg`

    const metrosLinealesDisplay = form.querySelector('[data-consecutivo-form-target="metrosLinealesDisplay"]')
    if (metrosLinealesDisplay) metrosLinealesDisplay.textContent = `${metrosLineales.toFixed(2)} m`
    
    const pesoNetoHidden = form.querySelector('input[data-consecutivo-form-target="pesoNeto"]')
    if (pesoNetoHidden) pesoNetoHidden.value = pesoNeto.toFixed(3)
    
    const metrosLinealesHidden = form.querySelector('input[data-consecutivo-form-target="metrosLineales"]')
    if (metrosLinealesHidden) metrosLinealesHidden.value = metrosLineales.toFixed(2)
  }

  log(message) {
    // console.log(`[ConsecutivoScaleController] ${message}`)
  }
}