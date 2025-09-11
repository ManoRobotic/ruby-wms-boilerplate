import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ 
    "scaleWeightSection", 
    "manualWeightSection", 
    "manualModeCheckbox", 
    "pesoBrutoInput", 
    "pesoNetoDisplay", 
    "pesoCoreDisplay", 
    "metrosLinealesDisplay", 
    "especificacionesDisplay", 
    "pesoNeto", 
    "metrosLineales", 
    "pesoBrutoHidden", 
    "pesoBrutoManualHidden",
    "serialSection"
  ]

  connect() {
    this.toggleManualMode()
  }

  toggleManualMode() {
    if (this.manualModeCheckboxTarget.checked) {
      this.manualWeightSectionTarget.classList.remove('hidden')
      this.serialSectionTarget.classList.add('hidden')
      this.pesoBrutoInputTarget.disabled = false
    } else {
      this.manualWeightSectionTarget.classList.add('hidden')
      this.serialSectionTarget.classList.remove('hidden')
      this.pesoBrutoInputTarget.disabled = true
    }
  }

  calculateWeights() {
    const pesoBruto = parseFloat(this.pesoBrutoInputTarget.value) || 0
    // Assuming peso core is fixed at 200g, as seen in the form
    const pesoCoreGramos = 200
    const pesoCoreKg = pesoCoreGramos / 1000

    const pesoNeto = pesoBruto - pesoCoreKg

    this.pesoNetoTarget.value = pesoNeto.toFixed(3)
    this.pesoNetoDisplayTarget.textContent = `${pesoNeto.toFixed(3)} kg`
    this.pesoBrutoHiddenTarget.value = pesoBruto
    this.pesoBrutoManualHiddenTarget.value = pesoBruto

    // Assuming other values from the form
    const micras = 35
    const ancho_mm = 420
    if (pesoNeto > 0 && micras > 0 && ancho_mm > 0) {
      const metros = (pesoNeto * 1000000) / micras / (ancho_mm) / 0.92
      this.metrosLinealesTarget.value = metros.toFixed(4)
      this.metrosLinealesDisplayTarget.textContent = `${metros.toFixed(4)} m`
    } else {
      this.metrosLinealesTarget.value = "0.0000"
      this.metrosLinealesDisplayTarget.textContent = "0.0000 m"
    }
  }
}
