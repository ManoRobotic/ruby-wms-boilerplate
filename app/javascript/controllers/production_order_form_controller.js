import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const form = this.element.querySelector('form')
    if (form) {
      form.addEventListener('submit', this.handleSubmit.bind(this))
    }
  }
  
  handleSubmit(event) {
    event.preventDefault()
    const form = event.target
    const formData = new FormData(form)
    
    // Show loading state
    const submitButton = form.querySelector('input[type="submit"]')
    const originalText = submitButton.value
    submitButton.value = 'Creando...'
    submitButton.disabled = true
    
    fetch(form.action, {
      method: 'POST',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
        'Accept': 'application/json'
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.status === 'success') {
        // Show success toast immediately
        this.showToast('success', '¡Orden creada!', data.message)
        
        // Show notification toast for the production order
        this.showToast('notification', 'Nueva orden de producción', 
          `Se ha creado la orden ${data.production_order.order_number} para ${data.production_order.product_name}`, 
          8000)
        
        // Update notification count immediately if there's a counter
        this.updateNotificationCounter()
        
        // Force a poll for new notifications
        this.triggerNotificationPoll()
        
        // Redirect after showing toast
        setTimeout(() => {
          window.location.href = `/admin/production_orders/${data.production_order.id}`
        }, 1500)
        
      } else {
        this.showToast('error', 'Error', 'No se pudo crear la orden de producción')
        submitButton.value = originalText
        submitButton.disabled = false
      }
    })
    .catch(error => {
      console.error('Error:', error)
      this.showToast('error', 'Error', 'Ocurrió un error al crear la orden')
      submitButton.value = originalText
      submitButton.disabled = false
    })
  }
  
  showToast(type, title, message, duration = 5000) {
    const event = new CustomEvent('toast:show', {
      detail: { type, title, message, duration }
    })
    document.dispatchEvent(event)
  }
  
  updateNotificationCounter() {
    const countElement = document.querySelector('.notification-count')
    if (countElement) {
      const currentCount = parseInt(countElement.textContent) || 0
      countElement.textContent = currentCount + 1
    } else {
      // Create new count element if it doesn't exist
      const bellButton = document.querySelector('[data-dropdown-target="trigger"]')
      if (bellButton) {
        const countSpan = document.createElement('span')
        countSpan.className = 'notification-count ml-auto bg-red-500 text-xs rounded-full px-1 py-0.5 min-w-[16px] text-center'
        countSpan.textContent = '1'
        bellButton.appendChild(countSpan)
      }
    }
  }
  
  triggerNotificationPoll() {
    // Trigger an immediate notification poll
    const event = new CustomEvent('notifications:poll')
    document.dispatchEvent(event)
  }
}