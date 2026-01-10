import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["weight"]

  connect() {
    this.log("Conectado y escuchando eventos de peso.")
    // El bind(this) es crucial para asegurar que 'this' dentro de handleWeightUpdate
    // se refiera a la instancia del controlador.
    this.boundHandleWeightUpdate = this.handleWeightUpdate.bind(this)
    document.addEventListener("serial:weightUpdate", this.boundHandleWeightUpdate)
  }

  disconnect() {
    this.log("Desconectado, dejando de escuchar eventos de peso.")
    document.removeEventListener("serial:weightUpdate", this.boundHandleWeightUpdate)
  }

  /**
   * Este método se activa cuando el `serial_controller` emite un evento `weightUpdate`.
   * @param {CustomEvent} event - El evento que contiene los datos del peso.
   */
  handleWeightUpdate(event) {
    const { weight, timestamp } = event.detail
    this.log(`Evento de peso recibido: ${weight}`)
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
    console.log(`[ConsecutivoScaleController] ${message}`)
  }
}