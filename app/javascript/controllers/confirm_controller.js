import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="confirm"
export default class extends Controller {
  static values = { 
    message: { type: String, default: "¿Estás seguro?" },
    title: { type: String, default: "Confirmar acción" }
  }

  connect() {
    // Remove any default Rails confirm behavior
    this.element.removeAttribute('data-confirm')
    this.element.removeAttribute('data-turbo-confirm')
  }

  confirm(event) {
    event.preventDefault()
    
    // Show confirmation dialog
    if (this.showConfirmDialog()) {
      this.proceedWithAction()
    }
  }

  showConfirmDialog() {
    // Use native confirm for now, can be enhanced with a custom modal later
    return window.confirm(this.messageValue)
  }

  proceedWithAction() {
    const element = this.element
    
    if (element.tagName === 'A') {
      // Handle link elements
      window.location.href = element.href
    } else if (element.tagName === 'BUTTON' || element.tagName === 'INPUT') {
      // Handle form submissions
      const form = element.closest('form')
      if (form) {
        form.submit()
      }
    }
  }

  // Enhanced version with custom modal (optional)
  showCustomConfirmDialog() {
    return new Promise((resolve) => {
      // Create custom modal
      const modal = this.createModal()
      document.body.appendChild(modal)
      
      const confirmBtn = modal.querySelector('[data-action="confirm"]')
      const cancelBtn = modal.querySelector('[data-action="cancel"]')
      
      const cleanup = () => {
        document.body.removeChild(modal)
      }
      
      confirmBtn.addEventListener('click', () => {
        cleanup()
        resolve(true)
      }, { once: true })
      
      cancelBtn.addEventListener('click', () => {
        cleanup()
        resolve(false)
      }, { once: true })
    })
  }

  createModal() {
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50'
    modal.innerHTML = `
      <div class="bg-white rounded-lg p-6 max-w-sm mx-4">
        <h3 class="text-lg font-medium text-gray-900 mb-4">${this.titleValue}</h3>
        <p class="text-sm text-gray-500 mb-6">${this.messageValue}</p>
        <div class="flex justify-end space-x-3">
          <button data-action="cancel" class="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 rounded-md hover:bg-gray-200">
            Cancelar
          </button>
          <button data-action="confirm" class="px-4 py-2 text-sm font-medium text-white bg-red-600 rounded-md hover:bg-red-700">
            Confirmar
          </button>
        </div>
      </div>
    `
    return modal
  }
}