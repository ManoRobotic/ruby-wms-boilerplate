import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["count"]
  
  connect() {
    this.controllerId = Math.random().toString(36).substr(2, 9)
    console.log(`🔔 NotificationsController connected! ID: ${this.controllerId}`)
    
    // Check if another notifications controller is already active
    if (window.activeNotificationsController) {
      console.warn(`⚠️ Another NotificationsController already active. Skipping this one: ${this.controllerId}`)
      return
    }
    
    window.activeNotificationsController = this.controllerId
    console.log(`✅ NotificationsController ${this.controllerId} is now active`)
    
    // Listen for new notifications
    document.addEventListener('notification:new', this.handleNewNotification.bind(this))
    document.addEventListener('toast:show', this.handleToastShow.bind(this))
    document.addEventListener('notifications:poll', this.handleImmediatePoll.bind(this))
    
    // Initialize toast container
    this.createToastContainer()
    
    // Connect to ActionCable for real-time notifications
    this.connectToCable()
  }
  
  disconnect() {
    console.log(`🔌 NotificationsController ${this.controllerId} disconnecting`)
    
    if (window.activeNotificationsController === this.controllerId) {
      window.activeNotificationsController = null
      console.log(`✅ NotificationsController ${this.controllerId} deactivated`)
      
      document.removeEventListener('notification:new', this.handleNewNotification.bind(this))
      document.removeEventListener('toast:show', this.handleToastShow.bind(this))
      document.removeEventListener('notifications:poll', this.handleImmediatePoll.bind(this))
      this.disconnectFromCable()
      this.stopPolling()
      this.stopImmediatePolling()
      
      // Clean up global reference
      if (window.showNotificationToast) {
        delete window.showNotificationToast
      }
    }
  }
  
  connectToCable() {
    // Import ActionCable consumer
    const consumer = (window.App && window.App.cable) || window.createConsumer?.('/cable')
    
    console.log('🔌 Checking ActionCable consumer:', consumer)
    if (!consumer) {
      console.warn('❌ ActionCable consumer not available')
      return
    }
    console.log('✅ ActionCable consumer found, creating subscription...')

    // Subscribe to notifications channel
    this.subscription = consumer.subscriptions.create("NotificationsChannel", {
      received: (data) => {
        // Only process if this is the active controller
        if (window.activeNotificationsController !== this.controllerId) {
          console.log(`⏭️ Ignoring message in inactive controller ${this.controllerId}`)
          return
        }
        
        if (data.type === 'new_notification' && data.notification) {
          console.log(`📡 WebSocket notification received by ${this.controllerId}:`, data.notification)
          
          // Prevent duplicate toasts by checking if one with same content exists
          const existingToasts = document.querySelectorAll('#toast-container > div')
          const duplicateExists = Array.from(existingToasts).some(toast => {
            const messageEl = toast.querySelector('.text-sm')
            return messageEl && messageEl.textContent.includes(data.notification.message)
          })
          
          if (!duplicateExists) {
            // Show toast immediately when receiving WebSocket message via global function
            if (window.showToast) {
              window.showToast(
                data.notification.type || 'notification',
                data.notification.title,
                data.notification.message,
                data.notification.duration || 15000
              )
            } else {
              // Fallback: dispatch event
              const event = new CustomEvent('toast:show', {
                detail: {
                  type: data.notification.type || 'notification',
                  title: data.notification.title,
                  message: data.notification.message,
                  duration: data.notification.duration || 15000
                }
              })
              document.dispatchEvent(event)
            }
            
            // Update notification count
            this.incrementNotificationCount()
          } else {
            console.log('⏭️ Skipping duplicate toast notification')
          }
        }
      },
      
      connected: () => {
        console.log('✅ Connected to NotificationsChannel')
      },
      
      disconnected: () => {
        console.log('❌ Disconnected from NotificationsChannel')
      },
      
      rejected: () => {
        console.log('❌ NotificationsChannel subscription rejected')
      }
    })
  }

  disconnectFromCable() {
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
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
  
  showToast(type, title, message, duration = 15000) {
    console.log('🍞 showToast called:', { type, title, message, duration })
    
    const container = document.querySelector('#toast-container')
    if (!container) {
      console.error('❌ Toast container not found!')
      return
    }
    console.log('✅ Toast container found:', container)
    
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
    
    setTimeout(() => {
      toast.classList.remove('translate-x-full', 'opacity-0')
      toast.classList.add('translate-x-0', 'opacity-100')
      console.log('🎬 Toast animated in')
    }, 100)
    
    const closeBtn = toast.querySelector('.toast-close')
    closeBtn.addEventListener('click', () => this.removeToast(toast))
    
    if (duration > 0) {
      setTimeout(() => this.removeToast(toast), duration)
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
    const notificationElement = event.currentTarget.closest('.notification-item')
    const notificationId = notificationElement?.dataset.notificationId
    
    if (!notificationId) {
      console.error('No notification ID found')
      return
    }
    
    fetch(`/admin/notifications/${notificationId}/mark_read`, {
      method: 'PATCH',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
        'Content-Type': 'application/json',
      }
    })
    .then(response => {
      if (response.ok) {
        // Remove unread styling immediately
        notificationElement.classList.remove('bg-blue-50')
        const unreadIndicator = notificationElement.querySelector('.unread-indicator')
        if (unreadIndicator) {
          unreadIndicator.remove()
        }
        
        // Update notification counter
        this.updateNotificationCount()
        
        // Show success toast
        this.showToast('success', 'Notificación marcada como leída', '', 3000)
        
        // If the notification had an action_url, navigate to it after marking as read
        const actionLink = event.currentTarget.closest('a[href]')
        if (actionLink && actionLink.href && !event.ctrlKey && !event.metaKey) {
          setTimeout(() => {
            window.location.href = actionLink.href
          }, 500)
        }
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
  
  startImmediatePolling() {
    this.lastImmediateCheck = new Date().toISOString()
    this.immediatePollingInterval = setInterval(() => {
      this.pollForImmediateNotifications()
    }, 2000) // Poll every 2 seconds for immediate notifications
  }
  
  stopImmediatePolling() {
    if (this.immediatePollingInterval) {
      clearInterval(this.immediatePollingInterval)
      this.immediatePollingInterval = null
    }
  }
  
  async pollForImmediateNotifications() {
    try {
      const response = await fetch(`/admin/notifications/poll_immediate?last_check=${encodeURIComponent(this.lastImmediateCheck)}`, {
        method: 'GET',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
          'Content-Type': 'application/json',
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        this.lastImmediateCheck = data.last_check
        
        // Show toasts for immediate notifications
        data.immediate_notifications.forEach(notification => {
          this.showToast('notification', notification.title, notification.message, notification.duration || 10000)
          // Update notification counter
          this.incrementNotificationCount()
        })
        
        // Also poll for regular notifications if we got immediate ones
        if (data.immediate_notifications.length > 0) {
          this.pollForNotifications()
        }
      }
    } catch (error) {
      console.error('Error polling for immediate notifications:', error)
    }
  }
}

// Global notification helper
window.showNotificationToast = (type, title, message, duration) => {
  const event = new CustomEvent('toast:show', {
    detail: { type, title, message, duration }
  })
  document.dispatchEvent(event)
}