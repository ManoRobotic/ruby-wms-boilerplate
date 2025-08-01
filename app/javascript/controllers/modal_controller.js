import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="modal"
export default class extends Controller {
  static targets = ["container", "backdrop", "content"]
  static classes = ["open", "closed"]
  static values = { 
    closeOnBackdrop: { type: Boolean, default: true },
    closeOnEscape: { type: Boolean, default: true }
  }

  connect() {
    this.boundKeyHandler = this.handleKeydown.bind(this)
  }

  disconnect() {
    this.removeEventListeners()
  }

  open() {
    this.element.classList.remove('hidden')
    this.element.classList.add(this.openClass)
    this.element.classList.remove(this.closedClass)
    
    // Prevent body scroll
    document.body.style.overflow = 'hidden'
    
    // Add event listeners
    this.addEventListeners()
    
    // Focus trap
    this.setupFocusTrap()
    
    // Dispatch custom event
    this.dispatch('opened')
  }

  close() {
    this.element.classList.add(this.closedClass)
    this.element.classList.remove(this.openClass)
    
    // Restore body scroll
    document.body.style.overflow = ''
    
    // Remove event listeners
    this.removeEventListeners()
    
    // Hide after animation
    setTimeout(() => {
      this.element.classList.add('hidden')
    }, 300)
    
    // Dispatch custom event
    this.dispatch('closed')
  }

  toggle() {
    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }

  isOpen() {
    return this.element.classList.contains(this.openClass)
  }

  backdropClicked(event) {
    if (this.closeOnBackdropValue && event.target === this.backdropTarget) {
      this.close()
    }
  }

  contentClicked(event) {
    // Prevent backdrop click when clicking inside content
    event.stopPropagation()
  }

  handleKeydown(event) {
    if (this.closeOnEscapeValue && event.key === 'Escape') {
      this.close()
    }
    
    // Handle tab for focus trap
    if (event.key === 'Tab') {
      this.handleTabKey(event)
    }
  }

  addEventListeners() {
    document.addEventListener('keydown', this.boundKeyHandler)
  }

  removeEventListeners() {
    document.removeEventListener('keydown', this.boundKeyHandler)
  }

  setupFocusTrap() {
    const focusableElements = this.element.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    )
    
    this.firstFocusableElement = focusableElements[0]
    this.lastFocusableElement = focusableElements[focusableElements.length - 1]
    
    // Focus first element
    if (this.firstFocusableElement) {
      this.firstFocusableElement.focus()
    }
  }

  handleTabKey(event) {
    if (!this.firstFocusableElement || !this.lastFocusableElement) return
    
    if (event.shiftKey) {
      // Shift + Tab
      if (document.activeElement === this.firstFocusableElement) {
        event.preventDefault()
        this.lastFocusableElement.focus()
      }
    } else {
      // Tab
      if (document.activeElement === this.lastFocusableElement) {
        event.preventDefault()
        this.firstFocusableElement.focus()
      }
    }
  }
}