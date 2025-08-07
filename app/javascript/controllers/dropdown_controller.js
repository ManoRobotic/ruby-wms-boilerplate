import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "menu", "icon"]

  connect() {
    this.outsideClickHandler = this.handleOutsideClick.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClickHandler)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    if (this.menuTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    // Close other dropdowns first
    document.querySelectorAll('[data-controller*="dropdown"]').forEach(dropdown => {
      if (dropdown !== this.element) {
        const controller = this.application.getControllerForElementAndIdentifier(dropdown, "dropdown")
        if (controller) controller.close()
      }
    })

    this.menuTarget.classList.remove("hidden")
    
    if (this.hasIconTarget) {
      this.iconTarget.classList.add("rotate-180")
    }
    
    // Add outside click listener
    setTimeout(() => {
      document.addEventListener("click", this.outsideClickHandler)
    }, 0)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    
    if (this.hasIconTarget) {
      this.iconTarget.classList.remove("rotate-180")
    }
    
    document.removeEventListener("click", this.outsideClickHandler)
  }

  handleOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }
}