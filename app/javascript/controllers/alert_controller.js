import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="alert"
export default class extends Controller {
  static values = { 
    autoClose: { type: Boolean, default: true },
    delay: { type: Number, default: 5000 }
  }

  connect() {
    if (this.autoCloseValue) {
      this.scheduleClose()
    }
  }

  scheduleClose() {
    this.timeout = setTimeout(() => {
      this.close()
    }, this.delayValue)
  }

  close() {
    this.element.style.display = "none"
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  // Allow manual closing by clicking
  dismiss() {
    this.close()
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }
}