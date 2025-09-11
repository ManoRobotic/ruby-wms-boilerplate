import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { target: String, message: String }
  
  connect() {
    console.log("🔄 CloseModal controller connected, closing:", this.targetValue)
    this.closeTargetModal()
    // Remove this element immediately
    setTimeout(() => {
      if (this.element && this.element.parentNode) {
        this.element.remove()
        console.log("🗑️ CloseModal element removed")
      }
    }, 100)
  }
  
  closeTargetModal() {
    const modalElement = document.getElementById(this.targetValue)
    if (modalElement) {
      console.log("✅ Found modal, dispatching close event to:", this.targetValue)
      modalElement.dispatchEvent(new Event("dialog:close"))
      
      // Show toast
      const message = this.hasMessageValue ? this.messageValue : 'Operación exitosa'
      if (window.showToast) {
        window.showToast('success', '', message)
      }
    } else {
      console.log("❌ Modal not found:", this.targetValue)
    }
  }
}