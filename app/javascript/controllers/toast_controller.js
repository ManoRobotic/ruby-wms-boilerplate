import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]
  
  connect() {
    this.createToastContainer()
  }
  
  createToastContainer() {
    if (!document.querySelector('#toast-container')) {
      const container = document.createElement('div')
      container.id = 'toast-container'
      container.className = 'fixed top-4 right-4 z-50 space-y-2'
      document.body.appendChild(container)
    }
  }
  
  show(event) {
    const { type = 'info', title, message, duration = 5000 } = event.detail
    this.showToast(type, title, message, duration)
  }
  
  showToast(type, title, message, duration = 5000) {
    const container = document.querySelector('#toast-container')
    if (!container) return
    
    const toast = document.createElement('div')
    toast.className = `transform transition-all duration-300 ease-in-out translate-x-full opacity-0 max-w-sm w-full bg-white shadow-lg rounded-lg pointer-events-auto ring-1 ring-black ring-opacity-5 overflow-hidden`
    
    const typeConfig = {
      success: {
        iconBg: 'bg-green-100',
        iconColor: 'text-green-600',
        icon: '✓',
        borderColor: 'border-green-200'
      },
      error: {
        iconBg: 'bg-red-100',
        iconColor: 'text-red-600',
        icon: '✕',
        borderColor: 'border-red-200'
      },
      warning: {
        iconBg: 'bg-yellow-100',
        iconColor: 'text-yellow-600',
        icon: '⚠',
        borderColor: 'border-yellow-200'
      },
      info: {
        iconBg: 'bg-blue-100',
        iconColor: 'text-blue-600',
        icon: 'ℹ',
        borderColor: 'border-blue-200'
      },
      notification: {
        iconBg: 'bg-purple-100',
        iconColor: 'text-purple-600',
        icon: '🔔',
        borderColor: 'border-purple-200'
      }
    }
    
    const config = typeConfig[type] || typeConfig.info
    
    toast.innerHTML = `
      <div class="flex items-start p-4">
        <div class="flex-shrink-0">
          <div class="${config.iconBg} rounded-full p-2">
            <span class="${config.iconColor} text-sm font-semibold">${config.icon}</span>
          </div>
        </div>
        <div class="ml-3 flex-1">
          ${title ? `<p class="text-sm font-medium text-gray-900">${title}</p>` : ''}
          <p class="text-sm text-gray-500">${message}</p>
        </div>
        <div class="ml-4 flex-shrink-0 flex">
          <button class="toast-close bg-white rounded-md inline-flex text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500">
            <span class="sr-only">Cerrar</span>
            <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
            </svg>
          </button>
        </div>
      </div>
    `
    
    container.appendChild(toast)
    
    // Show toast with animation
    setTimeout(() => {
      toast.classList.remove('translate-x-full', 'opacity-0')
      toast.classList.add('translate-x-0', 'opacity-100')
    }, 100)
    
    // Set up close button
    const closeBtn = toast.querySelector('.toast-close')
    closeBtn.addEventListener('click', () => this.removeToast(toast))
    
    // Auto remove after duration
    if (duration > 0) {
      setTimeout(() => {
        this.removeToast(toast)
      }, duration)
    }
  }
  
  removeToast(toast) {
    toast.classList.add('translate-x-full', 'opacity-0')
    setTimeout(() => {
      if (toast.parentNode) {
        toast.parentNode.removeChild(toast)
      }
    }, 300)
  }
  
  // Static method to show toast from anywhere
  static showToast(type, title, message, duration = 5000) {
    const event = new CustomEvent('toast:show', {
      detail: { type, title, message, duration }
    })
    document.dispatchEvent(event)
  }
}

// Global toast helper
window.showToast = (type, title, message, duration) => {
  const event = new CustomEvent('toast:show', {
    detail: { type, title, message, duration }
  })
  document.dispatchEvent(event)
}