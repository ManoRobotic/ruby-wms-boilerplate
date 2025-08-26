import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop", "dialog"]

  connect() {
    console.log("Dialog controller connected")
    this.bindTriggers()
  }

  bindTriggers() {
    // Find trigger buttons for this dialog
    const dialogId = this.element.getAttribute("data-dialog-backdrop")
    const triggers = document.querySelectorAll(`[data-dialog-target="${dialogId}"]`)
    
    triggers.forEach(trigger => {
      trigger.addEventListener("click", (e) => {
        e.preventDefault()
        this.open()
      })
    })

    // Bind close buttons
    const closeButtons = this.element.querySelectorAll("[data-dialog-close]")
    closeButtons.forEach(button => {
      button.addEventListener("click", (e) => {
        e.preventDefault()
        this.close()
      })
    })

    // Close on backdrop click
    if (this.element.hasAttribute("data-dialog-backdrop-close")) {
      this.element.addEventListener("click", (e) => {
        if (e.target === this.element) {
          this.close()
        }
      })
    }
  }

  open() {
    console.log("Opening dialog")
    this.element.classList.remove("pointer-events-none", "opacity-0")
    this.element.classList.add("pointer-events-auto", "opacity-100")
    document.body.style.overflow = "hidden"
  }

  close() {
    console.log("Closing dialog")
    this.element.classList.add("pointer-events-none", "opacity-0")
    this.element.classList.remove("pointer-events-auto", "opacity-100")
    document.body.style.overflow = ""
  }
}