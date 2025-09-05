import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit", "pesoBruto", "pesoNeto", "pesoCore", "micras", "ancho", "metros"]

  connect() {
    // Find the submit button if not explicitly defined
    if (!this.hasSubmitTarget) {
      this.submitTarget = this.element.querySelector('input[type="submit"]') || 
                         this.element.querySelector('button[type="submit"]')
    }
    
    // Add event listeners to weight fields
    this.setupEventListeners()
    
    // Initial validation
    this.validateForm()
  }

  setupEventListeners() {
    // Listen for input events on all relevant fields
    if (this.hasPesoBrutoTarget) {
      this.pesoBrutoTarget.addEventListener('input', this.handleInput.bind(this))
    }
    
    if (this.hasPesoCoreTarget) {
      this.pesoCoreTarget.addEventListener('input', this.handleInput.bind(this))
    }
    
    if (this.hasMicrasTarget) {
      this.micrasTarget.addEventListener('input', this.handleInput.bind(this))
    }
    
    if (this.hasAnchoTarget) {
      this.anchoTarget.addEventListener('input', this.handleInput.bind(this))
    }
  }

  handleInput() {
    this.calculateWeights()
    this.validateForm()
  }

  calculateWeights() {
    if (!this.hasPesoBrutoTarget || !this.hasPesoNetoTarget) return
    
    const pesoBruto = parseFloat(this.pesoBrutoTarget.value) || 0
    const pesoCore = this.hasPesoCoreTarget ? parseFloat(this.pesoCoreTarget.value) || 0 : 0
    const micras = this.hasMicrasTarget ? parseFloat(this.micrasTarget.value) || 0 : 0
    const ancho = this.hasAnchoTarget ? parseFloat(this.anchoTarget.value) || 0 : 0
    
    // Calcular peso neto
    const pesoNeto = pesoBruto - (pesoCore / 1000)
    this.pesoNetoTarget.value = pesoNeto.toFixed(3)
    
    // Calcular metros lineales if we have all required targets
    if (this.hasMetrosTarget) {
      if (pesoNeto > 0 && micras > 0 && ancho > 0) {
        const metros = (pesoNeto * 1000000) / micras / ancho / 0.92
        this.metrosTarget.value = metros.toFixed(4)
      } else {
        this.metrosTarget.value = ''
      }
    }
  }

  validateForm() {
    // Check if we have a valid weight
    const hasValidWeight = this.hasValidWeight()
    
    // Enable/disable submit button
    if (this.submitTarget) {
      this.submitTarget.disabled = !hasValidWeight
      
      // Update button style
      if (hasValidWeight) {
        this.submitTarget.classList.remove('opacity-50', 'cursor-not-allowed')
        this.submitTarget.classList.add('hover:bg-emerald-700')
      } else {
        this.submitTarget.classList.add('opacity-50', 'cursor-not-allowed')
        this.submitTarget.classList.remove('hover:bg-emerald-700')
      }
    }
  }

  hasValidWeight() {
    // Check if peso bruto is provided and greater than 0
    if (this.hasPesoBrutoTarget) {
      const pesoBruto = parseFloat(this.pesoBrutoTarget.value)
      return !isNaN(pesoBruto) && pesoBruto > 0
    }
    
    // If peso bruto doesn't exist, check peso neto
    if (this.hasPesoNetoTarget) {
      const pesoNeto = parseFloat(this.pesoNetoTarget.value)
      return !isNaN(pesoNeto) && pesoNeto > 0
    }
    
    // If neither field exists, default to false
    return false
  }

  // Allow manual triggering of validation
  validateForm(event) {
    this.handleInput()
  }
}