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
                
        // Redirect immediately
        window.location.href = `/admin/production_orders/${data.production_order.id}`
        
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
    const countElement = document.querySelector('.notification-count')
    if (countElement) {
      const currentCount = parseInt(countElement.textContent.replace('+', '')) || 0
      const newCount = currentCount + 1
      countElement.textContent = newCount > 99 ? "99+" : newCount.toString()
      
      // Make sure the indicator is visible
      countElement.style.display = 'flex'
    } else {
      // Create new count element if it doesn't exist
      const indicatorContainer = document.querySelector('.indicator')
      if (indicatorContainer) {
        const countSpan = document.createElement('span')
        countSpan.className = 'notification-count indicator-item badge bg-red-500 text-white text-xs font-medium border-0 min-w-[20px] h-5 flex items-center justify-center'
        countSpan.textContent = '1'
        indicatorContainer.insertBefore(countSpan, indicatorContainer.firstChild)
      }
    }
  }
}