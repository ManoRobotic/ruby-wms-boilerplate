import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]
  
  connect() {
    console.log('🍞 Toast controller connected!')
    this.createToastContainer()
    
    // Listen for toast:show events
    document.addEventListener('toast:show', this.show.bind(this))
    console.log('👂 Toast event listener attached')
  }

  disconnect() {
    document.removeEventListener('toast:show', this.show.bind(this))
    console.log('🔌 Toast event listener removed')
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
    console.log('🎬 Toast show event received:', event.detail)
    const { type = 'info', title, message, duration = 5000 } = event.detail
    this.showToast(type, title, message, duration)
  }
  
  showToast(type, title, message, duration = 15000) {
    console.log('🍞 showToast called:', { type, title, message, duration })
    
    const container = document.querySelector('#toast-container')
    if (!container) {
      console.error('❌ Toast container not found!')
      return
    }
    console.log('✅ Toast container found:', container)
    
    // Prevent duplicate toasts by checking if one with same content exists
    const existingToasts = container.querySelectorAll('div[role="alert"]')
    const duplicateExists = Array.from(existingToasts).some(toast => {
      const messageEl = toast.querySelector('.text-sm')
      return messageEl && messageEl.textContent.includes(message)
    })
    
    if (duplicateExists) {
      console.log('⏭️ Skipping duplicate toast')
      return
    }
    
    const toast = document.createElement('div')
    toast.className = `transform transition-all duration-300 ease-in-out translate-x-full opacity-0 flex items-center w-full max-w-xs p-4 mb-4 text-gray-500 bg-white rounded-lg shadow-sm dark:text-gray-400 dark:bg-gray-800`
    toast.setAttribute('role', 'alert')
    
    const typeConfig = {
      success: { 
        iconBg: 'text-green-500 bg-green-100 dark:bg-green-800 dark:text-green-200',
        icon: `<svg class="w-5 h-5" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="currentColor" viewBox="0 0 20 20">
                <path d="M10 .5a9.5 9.5 0 1 0 9.5 9.5A9.51 9.51 0 0 0 10 .5Zm3.707 8.207-4 4a1 1 0 0 1-1.414 0l-2-2a1 1 0 0 1 1.414-1.414L9 10.586l3.293-3.293a1 1 0 0 1 1.414 1.414Z"/>
              </svg>`
      },
      error: { 
        iconBg: 'text-red-500 bg-red-100 dark:bg-red-800 dark:text-red-200',
        icon: `<svg class="w-5 h-5" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="currentColor" viewBox="0 0 20 20">
                <path d="M10 .5a9.5 9.5 0 1 0 9.5 9.5A9.51 9.51 0 0 0 10 .5Zm3.707 11.793a1 1 0 1 1-1.414 1.414L10 11.414l-2.293 2.293a1 1 0 0 1-1.414-1.414L8.586 10 6.293 7.707a1 1 0 0 1 1.414-1.414L10 8.586l2.293-2.293a1 1 0 0 1 1.414 1.414L11.414 10l2.293 2.293Z"/>
              </svg>`
      },
      warning: { 
        iconBg: 'text-orange-500 bg-orange-100 dark:bg-orange-700 dark:text-orange-200',
        icon: `<svg class="w-5 h-5" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="currentColor" viewBox="0 0 20 20">
                <path d="M10 .5a9.5 9.5 0 1 0 9.5 9.5A9.51 9.51 0 0 0 10 .5ZM10 15a1 1 0 1 1 0-2 1 1 0 0 1 0 2Zm1-4a1 1 0 0 1-2 0V6a1 1 0 0 1 2 0v5Z"/>
              </svg>`
      },
      info: { 
        iconBg: 'text-blue-500 bg-blue-100 dark:bg-blue-800 dark:text-blue-200',
        icon: `<svg class="w-5 h-5" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="currentColor" viewBox="0 0 20 20">
                <path d="M10 .5a9.5 9.5 0 1 0 9.5 9.5A9.51 9.51 0 0 0 10 .5ZM9.5 4a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3ZM12 15H8a1 1 0 0 1 0-2h1v-3H8a1 1 0 0 1 0-2h2a1 1 0 0 1 1 1v4h1a1 1 0 0 1 0 2Z"/>
              </svg>`
      },
      notification: { 
        iconBg: 'text-purple-500 bg-purple-100 dark:bg-purple-800 dark:text-purple-200',
        icon: `<svg class="w-5 h-5" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="currentColor" viewBox="0 0 20 20">
                <path d="M10 .5a9.5 9.5 0 1 0 9.5 9.5A9.51 9.51 0 0 0 10 .5ZM9.5 4a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3ZM12 15H8a1 1 0 0 1 0-2h1v-3H8a1 1 0 0 1 0-2h2a1 1 0 0 1 1 1v4h1a1 1 0 0 1 0 2Z"/>
              </svg>`
      }
    }
    
    const config = typeConfig[type] || typeConfig.info
    
    // Create unique toast ID
    const toastId = `toast-${type}-${Date.now()}`
    toast.id = toastId
    
    toast.innerHTML = `
      <div class="inline-flex items-center justify-center shrink-0 w-8 h-8 ${config.iconBg} rounded-lg">
        ${config.icon}
        <span class="sr-only">${type} icon</span>
      </div>
      <div class="ms-3 text-sm font-normal">${title ? title + ': ' : ''}${message}</div>
      <button type="button" class="toast-close ms-auto -mx-1.5 -my-1.5 bg-white text-gray-400 hover:text-gray-900 rounded-lg focus:ring-2 focus:ring-gray-300 p-1.5 hover:bg-gray-100 inline-flex items-center justify-center h-8 w-8 dark:text-gray-500 dark:hover:text-white dark:bg-gray-800 dark:hover:bg-gray-700" data-dismiss-target="#${toastId}" aria-label="Close">
        <span class="sr-only">Close</span>
        <svg class="w-3 h-3" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 14 14">
          <path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="m1 1 6 6m0 0 6 6M7 7l6-6M7 7l-6 6"/>
        </svg>
      </button>
    `
    
    container.appendChild(toast)
    console.log('✅ Toast appended to container')
    
    // Show toast with animation
    setTimeout(() => {
      toast.classList.remove('translate-x-full', 'opacity-0')
      toast.classList.add('translate-x-0', 'opacity-100')
      console.log('🎬 Toast animated in')
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
    
    console.log('🎉 Toast setup complete')
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
  console.log('🌍 Global showToast called:', { type, title, message, duration })
  const event = new CustomEvent('toast:show', {
    detail: { type, title, message, duration }
  })
  console.log('📢 Dispatching toast:show event')
  document.dispatchEvent(event)
}