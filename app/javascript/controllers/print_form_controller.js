import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="print-form"
export default class extends Controller {
  static targets = ["weightField", "weightDisplay", "formatInfo", "submitButton"]

  connect() {
    console.log("Print form controller connected")
    
    // Escuchar actualizaciones de peso desde el scale reader
    document.addEventListener('scale:weight-updated', this.updateWeight.bind(this))
    
    // Agregar event listeners para los radio buttons
    this.addFormatListeners()
    
    // Agregar event listener para el submit del formulario
    this.element.addEventListener('submit', this.submitForm.bind(this))
    
    // Validación inicial
    this.validatePrintButton()
  }

  updateWeight(event) {
    const weight = event.detail.weight || 0.0
    
    // Actualizar campo oculto del formulario
    this.weightFieldTarget.value = weight.toFixed(1)
    
    // Actualizar display visual en la lista
    this.weightDisplayTargets.forEach(display => {
      display.textContent = `${weight.toFixed(1)} kg`
    })
    
    // Validar si se puede imprimir
    this.validatePrintButton()
    
    console.log(`Weight updated in form: ${weight} kg`)
  }

  addFormatListeners() {
    const radioButtons = this.element.querySelectorAll('input[name*="print_format"]')
    radioButtons.forEach(radio => {
      radio.addEventListener('change', this.updateFormatInfo.bind(this))
    })
  }

  updateFormatInfo(event) {
    const selectedFormat = event.target.value
    
    // Ocultar todas las listas de información
    const infoLists = ['bag-info', 'box-info', 'custom-info']
    infoLists.forEach(listId => {
      const list = document.getElementById(listId)
      if (list) list.classList.add('hidden')
    })
    
    // Mostrar la lista correspondiente al formato seleccionado
    const selectedInfo = document.getElementById(`${selectedFormat}-info`)
    if (selectedInfo) {
      selectedInfo.classList.remove('hidden')
    }
    
    console.log(`Print format changed to: ${selectedFormat}`)
  }

  validatePrintButton() {
    const currentWeight = parseFloat(this.weightFieldTarget.value)
    const warningDiv = document.getElementById('weight-warning')
    
    if (currentWeight > 0) {
      // Habilitar el botón si hay peso
      if (this.hasSubmitButtonTarget) {
        this.submitButtonTarget.disabled = false
      }
      // Ocultar warning
      if (warningDiv) {
        warningDiv.classList.add('hidden')
      }
    } else {
      // Deshabilitar el botón si no hay peso
      if (this.hasSubmitButtonTarget) {
        this.submitButtonTarget.disabled = true
      }
      // Mostrar warning
      if (warningDiv) {
        warningDiv.classList.remove('hidden')
      }
    }
  }

  // Interceptar el submit del formulario para validar peso
  submitForm(event) {
    const currentWeight = parseFloat(this.weightFieldTarget.value)
    
    if (currentWeight <= 0) {
      event.preventDefault()
      this.validatePrintButton()
      console.log('Form submission prevented: No weight captured')
      return false
    }
    
    console.log('Form submitted with weight:', currentWeight)
    return true
  }

  disconnect() {
    document.removeEventListener('scale:weight-updated', this.updateWeight.bind(this))
  }
}