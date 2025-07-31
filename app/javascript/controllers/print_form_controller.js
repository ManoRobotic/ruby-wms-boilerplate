import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="print-form"
export default class extends Controller {
  static targets = ["weightField", "weightDisplay"]

  connect() {
    console.log("Print form controller connected")
    
    // Escuchar actualizaciones de peso desde el scale reader
    document.addEventListener('scale:weight-updated', this.updateWeight.bind(this))
  }

  updateWeight(event) {
    const weight = event.detail.weight || 0.0
    
    // Actualizar campo oculto del formulario
    this.weightFieldTarget.value = weight.toFixed(1)
    
    // Actualizar display visual en la lista
    this.weightDisplayTarget.textContent = `${weight.toFixed(1)} kg`
    
    console.log(`Weight updated in form: ${weight} kg`)
  }

  disconnect() {
    document.removeEventListener('scale:weight-updated', this.updateWeight.bind(this))
  }
}