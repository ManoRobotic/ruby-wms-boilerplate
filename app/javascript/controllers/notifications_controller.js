import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["count"]
  
  connect() {
    // Listen for new notifications
    document.addEventListener('notification:new', this.handleNewNotification.bind(this))
    document.addEventListener('toast:show', this.handleToastShow.bind(this))
    document.addEventListener('notifications:poll', this.handleImmediatePoll.bind(this))
    
    // Initialize toast container
    this.createToastContainer()
    
    // Start polling for new notifications
    this.startPolling()
  }
  
  disconnect() {
    document.removeEventListener('notification:new', this.handleNewNotification.bind(this))
    document.removeEventListener('toast:show', this.handleToastShow.bind(this))
    document.removeEventListener('notifications:poll', this.handleImmediatePoll.bind(this))
    this.stopPolling()
  }
  
  createToastContainer() {
    if (!document.querySelector('#toast-container')) {
      const container = document.createElement('div')
      container.id = 'toast-container'
      container.className = 'fixed top-4 right-4 z-50 space-y-2'
      document.body.appendChild(container)
    }
  }
  
  handleNewNotification(event) {
    const { notification } = event.detail
    
    // Show toast for new notification
    this.showToast('notification', notification.title, notification.message)
    
    // Update notification count
    this.incrementNotificationCount()
  }
  
  handleToastShow(event) {
    const { type, title, message, duration } = event.detail
    this.showToast(type, title, message, duration)
  }
  
  showToast(type, title, message, duration = 5000) {
    const container = document.querySelector('#toast-container')
    if (!container) return
    
    const toast = document.createElement('div')
    toast.className = `transform transition-all duration-300 ease-in-out translate-x-full opacity-0 max-w-sm w-full bg-white shadow-lg rounded-lg pointer-events-auto ring-1 ring-black ring-opacity-5 overflow-hidden`
    
    const typeConfig = {
      success: { iconBg: 'bg-green-100', iconColor: 'text-green-600', icon: '✓' },
      error: { iconBg: 'bg-red-100', iconColor: 'text-red-600', icon: '✕' },
      warning: { iconBg: 'bg-yellow-100', iconColor: 'text-yellow-600', icon: '⚠' },
      info: { iconBg: 'bg-blue-100', iconColor: 'text-blue-600', icon: 'ℹ' },
      notification: { iconBg: 'bg-purple-100', iconColor: 'text-purple-600', icon: '🔔' }
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
          <button class="toast-close bg-white rounded-md inline-flex text-gray-400 hover:text-gray-500 focus:outline-none">
            <svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd" />
            </svg>
          </button>
        </div>
      </div>
    `
    
    container.appendChild(toast)
    
    setTimeout(() => {
      toast.classList.remove('translate-x-full', 'opacity-0')
      toast.classList.add('translate-x-0', 'opacity-100')
    }, 100)
    
    const closeBtn = toast.querySelector('.toast-close')
    closeBtn.addEventListener('click', () => this.removeToast(toast))
    
    if (duration > 0) {
      setTimeout(() => this.removeToast(toast), duration)
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
  
  markAllAsRead(event) {
    event.preventDefault()
    
    fetch('/admin/notifications/mark_all_read', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
        'Content-Type': 'application/json',
      }
    })
    .then(response => {
      if (response.ok) {
        this.showToast('success', 'Éxito', 'Todas las notificaciones han sido marcadas como leídas')
        setTimeout(() => window.location.reload(), 1000)
      } else {
        this.showToast('error', 'Error', 'No se pudieron marcar las notificaciones como leídas')
      }
    })
    .catch(error => {
      console.error('Error:', error)
      this.showToast('error', 'Error', 'Ocurrió un error al procesar la solicitud')
    })
  }

  markAsRead(event) {
    const notificationId = event.currentTarget.dataset.notificationId
    
    if (!notificationId) return
    
    fetch(`/admin/notifications/${notificationId}/mark_read`, {
      method: 'PATCH',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
        'Content-Type': 'application/json',
      }
    })
    .then(response => {
      if (response.ok) {
        const notificationElement = event.currentTarget.closest('.notification-item')
        if (notificationElement) {
          notificationElement.classList.remove('bg-blue-50')
          const unreadIndicator = notificationElement.querySelector('.unread-indicator')
          if (unreadIndicator) {
            unreadIndicator.remove()
          }
        }
        this.updateNotificationCount()
        this.showToast('success', 'Notificación marcada como leída')
      }
    })
    .catch(error => {
      console.error('Error:', error)
      this.showToast('error', 'Error al marcar la notificación')
    })
  }

  updateNotificationCount() {
    const countElement = document.querySelector('.notification-count')
    if (countElement) {
      const currentCount = parseInt(countElement.textContent)
      const newCount = Math.max(0, currentCount - 1)
      
      if (newCount === 0) {
        countElement.remove()
      } else {
        countElement.textContent = newCount
      }
    }
  }
  
  incrementNotificationCount() {
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
  
  startPolling() {
    this.lastPoll = new Date().toISOString()
    this.pollInterval = setInterval(() => {
      this.pollForNotifications()
    }, 30000) // Poll every 30 seconds
  }
  
  stopPolling() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
      this.pollInterval = null
    }
  }
  
  async pollForNotifications() {
    try {
      const response = await fetch(`/admin/notifications/poll?last_poll=${encodeURIComponent(this.lastPoll)}`, {
        method: 'GET',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
          'Content-Type': 'application/json',
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        
        // Update last poll time
        this.lastPoll = data.last_poll
        
        // Show toast for new notifications
        data.notifications.forEach(notification => {
          this.showToast('notification', notification.title, notification.message, 8000)
        })
        
        // Update notification count if needed
        if (data.notifications.length > 0) {
          this.updateNotificationCountFromServer(data.unread_count)
        }
      }
    } catch (error) {
      console.error('Error polling for notifications:', error)
    }
  }
  
  updateNotificationCountFromServer(serverCount) {
    const countElement = document.querySelector('.notification-count')
    if (serverCount > 0) {
      if (countElement) {
        countElement.textContent = serverCount
      } else {
        // Create new count element
        const bellButton = document.querySelector('[data-dropdown-target="trigger"]')
        if (bellButton) {
          const countSpan = document.createElement('span')
          countSpan.className = 'notification-count ml-auto bg-red-500 text-xs rounded-full px-1 py-0.5 min-w-[16px] text-center'
          countSpan.textContent = serverCount
          bellButton.appendChild(countSpan)
        }
      }
    } else if (countElement) {
      countElement.remove()
    }
  }
  
  handleImmediatePoll(event) {
    // Force an immediate poll for notifications
    this.pollForNotifications()
  }
}

// Global notification helper
window.showNotificationToast = (type, title, message, duration) => {
  const event = new CustomEvent('toast:show', {
    detail: { type, title, message, duration }
  })
  document.dispatchEvent(event)
}