import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pesoNeto", "metrosLineales"]

  connect() {
    console.log("Consecutivo form controller connected")
    this.calculateWeights()
  }

  calculateWeights() {
    const pesoBruto = parseFloat(this.getFieldValue("peso_bruto")) || 0
    const alturaCm = parseFloat(this.getFieldValue("altura_cm")) || 0
    const micras = parseFloat(this.getFieldValue("micras")) || 0
    const anchoMm = parseFloat(this.getFieldValue("ancho_mm")) || 0

    // Core weight lookup table
    const coreWeightTable = {
      3: 72, 4: 96, 5: 120, 6: 144, 7: 168, 8: 192, 9: 216, 10: 240,
      11: 264, 12: 288, 13: 312, 14: 336, 15: 360, 16: 384, 17: 408, 18: 432,
      19: 456, 20: 480, 21: 504, 22: 528, 23: 552, 24: 576, 25: 600, 26: 624,
      27: 648, 28: 672, 29: 696, 30: 720, 31: 744, 32: 768, 33: 792, 34: 816,
      35: 840, 36: 864, 37: 888, 38: 912, 39: 936, 40: 960, 41: 984, 42: 1008,
      43: 1032, 44: 1056, 45: 1080, 46: 1104, 47: 1128, 48: 1152, 49: 1176, 50: 1200
    }

    // Get peso core from altura (ensure it's not 0)
    const pesoCoreGramos = coreWeightTable[Math.floor(alturaCm)] || 0

    // Calculate peso neto: peso bruto (kg) - (peso core (g) / 1000)
    let pesoNeto = pesoBruto - (pesoCoreGramos / 1000.0)
    
    // Ensure peso neto is not negative
    pesoNeto = Math.max(0, pesoNeto)
    
    // Calculate metros lineales: (peso neto * 1,000,000) / micras / ancho mm / 0.92
    let metrosLineales = 0
    if (pesoNeto > 0 && micras > 0 && anchoMm > 0) {
      metrosLineales = (pesoNeto * 1000000) / micras / anchoMm / 0.92
      metrosLineales = Math.max(0, metrosLineales)
    }

    // Update the readonly fields
    if (this.hasPesoNetoTarget) {
      this.pesoNetoTarget.value = pesoNeto.toFixed(3)
    }
    
    if (this.hasMetrosLinealesTarget) {
      this.metrosLinealesTarget.value = metrosLineales.toFixed(4)
    }

    // Also update hidden fields for form submission
    this.setFieldValue("peso_neto", pesoNeto.toFixed(3))
    this.setFieldValue("metros_lineales", metrosLineales.toFixed(4))
    this.setFieldValue("peso_core_gramos", pesoCoreGramos)
  }

  getFieldValue(fieldName) {
    const field = this.element.querySelector(`[name*="${fieldName}"]`) || 
                  this.element.querySelector(`input[id*="${fieldName}"]`)
    return field ? field.value : ""
  }

  setFieldValue(fieldName, value) {
    const field = this.element.querySelector(`[name*="${fieldName}"]`) || 
                  this.element.querySelector(`input[id*="${fieldName}"]`)
    if (field) {
      field.value = value
    }
  }

  // Handle form submission
  handleFormSubmit(event) {
    // Ensure calculations are up to date before submitting
    this.calculateWeights()
    
    // Add success handler for form submission
    const form = event.target
    if (form) {
      // Log form data for debugging
      const formData = new FormData(form)
      console.log('Form submission data:')
      for (let [key, value] of formData.entries()) {
        console.log(`${key}: ${value}`)
      }
    }
  }
}