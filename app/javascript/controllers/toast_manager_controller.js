import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "toast" ]
  static values = { 
    autoDismiss: { type: Boolean, default: true },
    dismissAfter: { type: Number, default: 5000 }
  }

  connect() {
    console.log("Toast manager controller connected")
    
    // Configurar auto-dismiss si está habilitado
    if (this.autoDismissValue) {
      this.setupAutoDismiss()
    }
    
    // Configurar eventos para botones de cierre
    this.setupCloseButtons()
  }

  setupAutoDismiss() {
    // Auto-remove after dismissAfter milliseconds
    setTimeout(() => {
      if (this.element.parentNode) {
        this.dismiss()
      }
    }, this.dismissAfterValue)
  }

  setupCloseButtons() {
    // Agregar evento para cerrar con el botón
    const closeButtons = this.element.querySelectorAll('button[aria-label="Close"]')
    closeButtons.forEach(button => {
      button.addEventListener('click', (e) => {
        e.preventDefault()
        this.dismiss()
      })
    })
  }

  dismiss() {
    if (this.element.parentNode) {
      // Agregar animación de salida
      this.element.style.transition = 'opacity 0.3s ease-out'
      this.element.style.opacity = '0'
      
      // Remover el elemento después de la transición
      setTimeout(() => {
        if (this.element.parentNode) {
          this.element.parentNode.removeChild(this.element)
        }
      }, 300)
    }
  }
}