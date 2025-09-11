import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("Auto close modal controller connected")
    // Close the consecutivo modal
    this.closeConsecutivoModal()
    
    // Show success toast
    if (window.showToast) {
      window.showToast('success', '', 'Consecutivo creado exitosamente')
    }
    
    // Remove this controller element after execution to prevent duplicates
    setTimeout(() => {
      if (this.element.parentNode) {
        this.element.parentNode.removeChild(this.element)
      }
    }, 100)
  }

  closeConsecutivoModal() {
    console.log("Attempting to close consecutivo modal")
    const modal = document.getElementById('consecutivo-modal')
    if (modal) {
      console.log("Found modal, dispatching close event")
      // Dispatch the close event that the dialog controller listens for
      modal.dispatchEvent(new CustomEvent('dialog:close'))
    } else {
      console.log("Modal not found")
    }
  }
}