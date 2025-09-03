import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    
    // Add a visual indicator that the controller connected (temporary for debugging)
    const indicator = document.createElement('div')
    document.body.appendChild(indicator)
    setTimeout(() => indicator.remove(), 4000)
    
    const form = this.element.querySelector('form')
    if (form) {
      form.addEventListener('submit', this.handleSubmit.bind(this))
    } else {
      console.warn('⚠️ No form found in production order form controller')
    }
  }

  disconnect() {
    console.log('📋 ProductionOrderFormController disconnected')
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
    
    // Safety timeout to reset button if something goes wrong
    const safetyTimeout = setTimeout(() => {
      submitButton.value = originalText
      submitButton.disabled = false
    }, 10000) // 10 seconds safety net

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
      clearTimeout(safetyTimeout) // Clear safety timeout on successful response
      
      if (data.status === 'success') {
        
        // Store toast data in sessionStorage to show after redirect
        sessionStorage.setItem('showToast', JSON.stringify({
          type: 'success',
          title: '¡Orden creada!',
          message: data.message
        }))
        
        // Update notification counter immediately
        this.updateNotificationCounter()
        
        // Clear any existing toasts that might be showing
        const existingToasts = document.querySelectorAll('[data-toast]')
        existingToasts.forEach(toast => toast.remove())
                
        // Add a small delay before redirect to allow notification update to register
        setTimeout(() => {
          window.location.href = `/admin/production_orders/${data.production_order.id}`
        }, 300)
        
      } else {
        console.error('Error creating production order:', data)
        submitButton.value = originalText
        submitButton.disabled = false
      }
    })
    .catch(error => {
      clearTimeout(safetyTimeout) // Clear safety timeout on error too
      console.error('Error creating production order:', error)
      submitButton.value = originalText
      submitButton.disabled = false
    })
  }
  
  updateNotificationCounter() {
    // Dispatch event to trigger notification update in notifications controller
    const notificationEvent = new CustomEvent('notifications:poll')
    document.dispatchEvent(notificationEvent)
    
    // Also update the counter directly as a fallback
    // Find the notification indicator container
    const indicatorContainer = document.querySelector('.notification-indicator')
    if (!indicatorContainer) return
    
    // Get existing count or start from 0
    const existingCountElement = indicatorContainer.querySelector('.notification-count')
    const currentCount = existingCountElement ? 
      (parseInt(existingCountElement.textContent.replace('+', '')) || 0) : 0
    const newCount = currentCount + 1
    
    // Remove existing count element if it exists
    if (existingCountElement) {
      existingCountElement.remove()
    }
    
    // Create and show the new notification count
    const countSpan = document.createElement('span')
    countSpan.className = 'notification-count inline-flex items-center justify-center px-2 py-1 text-xs font-bold leading-none text-red-100 bg-red-600 rounded-full'
    countSpan.textContent = newCount > 99 ? "99+" : newCount.toString()
    indicatorContainer.appendChild(countSpan)
  }
}