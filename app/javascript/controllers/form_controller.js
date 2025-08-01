import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="form"
export default class extends Controller {
  static targets = ["submit", "field", "error"]
  static classes = ["loading", "invalid", "valid"]
  static values = { 
    validateOnInput: { type: Boolean, default: false },
    submitOnce: { type: Boolean, default: true }
  }

  connect() {
    this.isSubmitting = false
    
    if (this.validateOnInputValue) {
      this.setupRealTimeValidation()
    }
    
    // Set up form submit handler
    this.element.addEventListener('submit', this.submit.bind(this))
  }

  setupRealTimeValidation() {
    this.fieldTargets.forEach(field => {
      field.addEventListener('input', this.validateField.bind(this))
      field.addEventListener('blur', this.validateField.bind(this))
    })
  }

  validateField(event) {
    const field = event.target
    const isValid = field.checkValidity()
    
    if (isValid) {
      this.markFieldValid(field)
    } else {
      this.markFieldInvalid(field)
    }
  }

  markFieldValid(field) {
    if (this.hasInvalidClass) {
      field.classList.remove(this.invalidClass)
    }
    if (this.hasValidClass) {
      field.classList.add(this.validClass)
    }
    this.hideFieldError(field)
  }

  markFieldInvalid(field) {
    if (this.hasValidClass) {
      field.classList.remove(this.validClass)
    }
    if (this.hasInvalidClass) {
      field.classList.add(this.invalidClass)
    }
    this.showFieldError(field)
  }

  showFieldError(field) {
    const errorElement = this.findOrCreateErrorElement(field)
    errorElement.textContent = field.validationMessage
    errorElement.style.display = 'block'
  }

  hideFieldError(field) {
    const errorElement = this.findErrorElement(field)
    if (errorElement) {
      errorElement.style.display = 'none'
    }
  }

  findOrCreateErrorElement(field) {
    let errorElement = this.findErrorElement(field)
    
    if (!errorElement) {
      errorElement = document.createElement('div')
      errorElement.className = 'text-red-500 text-sm mt-1'
      errorElement.setAttribute('data-form-target', 'error')
      field.parentNode.appendChild(errorElement)
    }
    
    return errorElement
  }

  findErrorElement(field) {
    return field.parentNode.querySelector('[data-form-target="error"]')
  }

  submit(event) {
    if (this.submitOnceValue && this.isSubmitting) {
      event.preventDefault()
      return
    }

    if (!this.element.checkValidity()) {
      event.preventDefault()
      this.highlightInvalidFields()
      return
    }

    if (this.submitOnceValue) {
      this.isSubmitting = true
      this.showLoadingState()
    }
  }

  highlightInvalidFields() {
    this.fieldTargets.forEach(field => {
      if (!field.checkValidity()) {
        this.markFieldInvalid(field)
      }
    })
  }

  showLoadingState() {
    if (this.hasSubmitTarget) {
      const submitButton = this.submitTarget
      submitButton.disabled = true
      
      // Only add loading class if it's defined
      if (this.hasLoadingClass) {
        submitButton.classList.add(this.loadingClass)
      }
      
      // Store original text
      this.originalSubmitText = submitButton.textContent
      submitButton.textContent = 'Procesando...'
    }
  }

  hideLoadingState() {
    if (this.hasSubmitTarget) {
      const submitButton = this.submitTarget
      submitButton.disabled = false
      
      // Only remove loading class if it's defined
      if (this.hasLoadingClass) {
        submitButton.classList.remove(this.loadingClass)
      }
      
      if (this.originalSubmitText) {
        submitButton.textContent = this.originalSubmitText
      }
    }
    
    this.isSubmitting = false
  }

  // Reset form state
  reset() {
    this.fieldTargets.forEach(field => {
      if (this.hasInvalidClass) {
        field.classList.remove(this.invalidClass)
      }
      if (this.hasValidClass) {
        field.classList.remove(this.validClass)
      }
      this.hideFieldError(field)
    })
    
    this.hideLoadingState()
  }

  // Handle Turbo events
  turboSubmitEnd() {
    this.hideLoadingState()
  }

  turboSubmitErrored() {
    this.hideLoadingState()
  }
}