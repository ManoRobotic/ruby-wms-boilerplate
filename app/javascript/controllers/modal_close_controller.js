import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { target: String, message: String }

  connect() {
    console.log("Modal close controller connected for target:", this.targetValue)
    // Wait a bit longer to ensure turbo stream is fully processed
    setTimeout(() => {
      console.log("About to call closeModal after timeout")
      this.closeModal()
    }, 150)
  }

  closeModal() {
    console.log("closeModal triggered for target:", this.targetValue)
    
    // Temporarily disable trigger buttons to prevent accidental clicks
    const dialogId = this.targetValue.replace('-modal', '-modal')
    const triggerButtons = document.querySelectorAll(`[data-dialog-target="${dialogId}"]`)
    
    triggerButtons.forEach(btn => {
      btn.disabled = true
      btn.style.pointerEvents = 'none'
    })
    
    const modalElement = document.getElementById(this.targetValue)
    if (modalElement) {
      console.log("Found modal element:", modalElement)
      
      // Get the dialog controller instance
      const dialogController = this.application.getControllerForElementAndIdentifier(modalElement, "dialog")
      
      if (dialogController) {
        console.log("Found dialog controller, calling closeModal")
        dialogController.closeModal()
        
        // Set additional protection against accidental reopening
        dialogController.lastClickTime = Date.now()
        setTimeout(() => {
          dialogController.lastClickTime = Date.now()
          console.log("Additional protection applied")
        }, 200)
        
      } else {
        console.log("Dialog controller not found, dispatching event")
        modalElement.dispatchEvent(new Event("dialog:close"))
      }
      
      // Show toast notification
      const message = this.hasMessageValue ? this.messageValue : 'Consecutivo guardado exitosamente.'
      if (window.showToast) {
        window.showToast('success', '', message)
      }
      
      // Re-enable trigger buttons after a delay
      setTimeout(() => {
        triggerButtons.forEach(btn => {
          btn.disabled = false
          btn.style.pointerEvents = ''
        })
      }, 300)
      
    } else {
      console.log("Modal element not found:", this.targetValue)
    }
    
    // Remove this trigger element immediately after execution
    setTimeout(() => {
      if (this.element && this.element.parentNode) {
        this.element.remove()
        console.log("Modal close trigger element removed")
      }
    }, 100)
  }
}