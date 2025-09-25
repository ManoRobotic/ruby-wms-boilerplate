import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["indicator"]
  
  connect() {
    this.controllerId = Math.random().toString(36).substring(2, 11)
    
    if (window.activeNotificationsController) {
      return
    }
    
    window.activeNotificationsController = this.controllerId
    
    // Check if we have clickable notification elements
    const clickableElements = this.element.querySelectorAll('[data-action*="markAsRead"]')
    
    document.addEventListener('notification:new', this.handleNewNotification.bind(this))
    // Removed toast:show listener to prevent conflict with toast_controller
    // Removed the immediate poll listener that was previously added but is no longer needed
    
    this.createToastContainer()
    
    this.connectToCable()
    
    // Initialize the notifications list DOM element
    this.notificationsListElement = document.getElementById('notifications-list')
  }
  
  disconnect() {
    
    if (window.activeNotificationsController === this.controllerId) {
      window.activeNotificationsController = null
      
      document.removeEventListener('notification:new', this.handleNewNotification.bind(this))
      this.disconnectFromCable()
      
      // Clear active toasts set
      if (this.activeToasts) {
        this.activeToasts.clear()
      }
      
      if (window.showNotificationToast) {
        delete window.showNotificationToast
      }
    }
  }
  
  connectToCable() {
    const consumer = (window.App && window.App.cable) || window.createConsumer?.('/cable')
    
    if (!consumer) {
      return
    }

    this.subscription = consumer.subscriptions.create("NotificationsChannel", {
      received: (data) => {
        if (window.activeNotificationsController !== this.controllerId) {
          return
        }
        
        if (data.type === 'new_notification' && data.notification) {
          // Create a unique key to prevent duplicate processing
          const notificationKey = `${data.notification.id}_${data.notification.title}_${data.notification.message}`
          
          // Check if we've already processed this notification recently
          if (this.recentNotifications && this.recentNotifications.has(notificationKey)) {
            return
          }
          
          // Track recent notifications to prevent duplicates
          if (!this.recentNotifications) {
            this.recentNotifications = new Set()
          }
          this.recentNotifications.add(notificationKey)
          
          // Clean up old notification keys after 30 seconds
          setTimeout(() => {
            if (this.recentNotifications) {
              this.recentNotifications.delete(notificationKey)
            }
          }, 30000)
          
          // Add the notification to the DOM list
          this.addNotificationToDOM(data.notification)
          
          // Show the notification as a toast
          this.showNotificationToast(data.notification)
          
          // Increment the notification count indicator
          this.incrementNotificationCount()
        }
      },
      
      connected: () => {
      },
      
      disconnected: () => {
      },
      
      rejected: () => {
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
    
    // Add the notification to the DOM list
    this.addNotificationToDOM(notification)
    
    // Show toast for new notification
    this.showNotificationToast(notification)
    
    // Update notification count
    this.incrementNotificationCount()
  }

  showNotificationToast(notification) {
    // Use the global toast system
    if (window.showToast) {
      window.showToast(
        'notification', 
        notification.title, 
        notification.message, 
        notification.duration || 8000
      )
    } else {
      // Fallback to event system
      const toastEvent = new CustomEvent('toast:show', {
        detail: { 
          type: 'notification', 
          title: notification.title, 
          message: notification.message, 
          duration: notification.duration || 8000 
        }
      })
      document.dispatchEvent(toastEvent)
    }
  }

  
  
  // Removed handleToastShow to prevent conflict with toast_controller
  
  showToast(type, title, message, duration = 15000) {
    
    // Create a unique key for this toast to prevent duplicates
    const toastKey = `${type}_${title}_${message}`.replace(/\s/g, '_')
    
    // Check if this exact toast is already being shown
    if (this.activeToasts && this.activeToasts.has(toastKey)) {
      return
    }
    
    // Initialize activeToasts if not exists
    if (!this.activeToasts) {
      this.activeToasts = new Set()
    }
    
    // Mark this toast as active
    this.activeToasts.add(toastKey)
    
    // Clear any existing duplicate toasts
    this.clearDuplicateToasts(title, message)
    
    const container = document.querySelector('#toast-container')
    if (!container) {
      this.activeToasts.delete(toastKey)
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
    
    setTimeout(() => {
      toast.classList.remove('translate-x-full', 'opacity-0')
      toast.classList.add('translate-x-0', 'opacity-100')
    }, 100)
    
    const closeBtn = toast.querySelector('.toast-close')
    closeBtn.addEventListener('click', () => this.removeToast(toast, toastKey))
    
    if (duration > 0) {
      setTimeout(() => this.removeToast(toast, toastKey), duration)
    }
    
  }
  
  removeToast(toast, toastKey = null) {
    toast.classList.add('translate-x-full', 'opacity-0')
    setTimeout(() => {
      if (toast.parentNode) {
        toast.parentNode.removeChild(toast)
      }
      // Remove from active toasts set
      if (toastKey && this.activeToasts) {
        this.activeToasts.delete(toastKey)
      }
    }, 300)
  }
  
  clearDuplicateToasts(title, message) {
    const container = document.querySelector('#toast-container')
    if (!container) return
    
    const existingToasts = container.querySelectorAll('div[role="alert"]')
    existingToasts.forEach(toast => {
      const messageEl = toast.querySelector('.text-sm')
      if (messageEl) {
        const fullText = messageEl.textContent || ''
        // Check if toast contains the same title and message
        if ((title && fullText.includes(title)) || (message && fullText.includes(message))) {
          this.removeToast(toast)
        }
      }
    })
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
      this.showToast('error', 'Error', 'Ocurrió un error al procesar la solicitud')
    })
  }

  markAsRead(event) {
    
    // Use currentTarget if available, otherwise fall back to target for processing check
    const processingElement = event.currentTarget || event.target
    
    // Check if this notification is already being processed
    if (processingElement && processingElement.dataset.processing) {
      return
    }
    
    event.preventDefault()
    event.stopPropagation() // Stop event from bubbling up
    
    // Mark as being processed
    if (processingElement) {
      processingElement.dataset.processing = 'true'
    }
    
    // Use currentTarget if available, otherwise fall back to target
    const clickedElement = event.currentTarget || event.target
    
    if (!clickedElement) {
      return
    }
    
    
    const notificationElement = clickedElement.closest('.notification-item')
    
    
    if (!notificationElement) {
      return
    }
    
    // Try to get notification ID from either the clicked element or the parent notification element
    let notificationId = clickedElement.dataset.notificationId || notificationElement.dataset.notificationId
    let actionUrl = clickedElement.dataset.notificationActionUrl
    
    
    if (!notificationId) {
      return
    }
    
    
    // Small delay to ensure DOM is stable and avoid race conditions
    setTimeout(() => {
      const url = `/admin/notifications/${notificationId}/mark_read`
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
      
      
      this.performMarkAsRead(url, csrfToken, notificationElement, actionUrl, event, processingElement)
    }, 50)
  }
  
  performMarkAsRead(url, csrfToken, notificationElement, actionUrl, event, processingElement) {
    fetch(url, {
      method: 'PATCH',
      headers: {
        'X-CSRF-Token': csrfToken,
        'Content-Type': 'application/json',
      }
    })
    .then(response => {
      
      if (response.ok) {
        
        notificationElement.classList.remove('bg-blue-50', 'border-l-4', 'border-l-blue-500')
        notificationElement.classList.remove('border-l-blue-500')
        const unreadIndicator = notificationElement.querySelector('.unread-indicator')
        if (unreadIndicator) {
          unreadIndicator.remove()
        }
        
        this.updateNotificationCount()
        
        
        if (actionUrl && actionUrl.trim() !== '' && !event.ctrlKey && !event.metaKey) {
          setTimeout(() => {
            window.location.href = actionUrl
          }, 800)
        }
      } else {
        response.text().then(text => {
        })
        this.showToast('error', 'Error al marcar la notificación')
      }
      
      // Clean up processing flag
      if (processingElement) {
        delete processingElement.dataset.processing
      }
    })
    .catch(error => {
      this.showToast('error', 'Error al marcar la notificación')
      
      // Clean up processing flag on error too
      if (processingElement) {
        delete processingElement.dataset.processing
      }
    })
  }

  updateNotificationCount() {
    const indicatorContainer = this.indicatorTarget;
    if (!indicatorContainer) return;

    let countElement = indicatorContainer.querySelector('.notification-count');
    if (countElement) {
      const currentCount = parseInt(countElement.textContent.replace('+', '')) || 0;
      const newCount = Math.max(0, currentCount - 1);

      if (newCount === 0) {
        countElement.remove();
      } else {
        countElement.textContent = newCount > 99 ? "99+" : newCount.toString();
      }
    }
  }

  incrementNotificationCount() {
    const indicatorContainer = this.indicatorTarget;
    if (!indicatorContainer) return;

    let countElement = indicatorContainer.querySelector('.notification-count');

    if (!countElement) {
      countElement = document.createElement('span');
      countElement.className = 'notification-count inline-flex items-center justify-center px-2 py-1 text-xs font-bold leading-none text-red-100 bg-red-600 rounded-full';
      indicatorContainer.appendChild(countElement);
    }
    
    const currentCount = parseInt(countElement.textContent.replace('+', '')) || 0;
    const newCount = currentCount + 1;
    
    countElement.textContent = newCount > 99 ? "99+" : newCount.toString();
  }
  
  
  
  addNotificationToDOM(notification) {
    if (!this.notificationsListElement) return;

    // Check if notification already exists in the list to prevent duplicates
    const existingNotification = this.notificationsListElement.querySelector(`[data-notification-id="${notification.id}"]`);
    if (existingNotification) {
      return; // Notification already exists in DOM
    }

    // Create a new notification item element
    const notificationItem = document.createElement('div');
    notificationItem.className = notification.read ? 
      'notification-item flex items-start p-4 border-b border-gray-200 cursor-pointer hover:bg-gray-50' : 
      'notification-item flex items-start p-4 border-b border-gray-200 bg-blue-50 border-l-4 border-l-blue-500 cursor-pointer hover:bg-blue-100';
    notificationItem.setAttribute('data-notification-id', notification.id);
    notificationItem.setAttribute('data-action', 'click->notifications#markAsRead');
    notificationItem.setAttribute('data-notification-id-param', notification.id);
    notificationItem.setAttribute('data-notification-action-url', notification.action_url || '');

    // Add unread indicator if not read
    const unreadIndicator = !notification.read ? '<span class="unread-indicator flex-shrink-0 w-3 h-3 bg-red-500 rounded-full mt-1 mr-3" aria-hidden="true"></span>' : '<span class="flex-shrink-0 w-3 h-3 mt-1 mr-3" aria-hidden="true"></span>';

    notificationItem.innerHTML = `
      ${unreadIndicator}
      <div class="flex-1 min-w-0">
        <p class="text-sm font-medium text-gray-900">${notification.title}</p>
        <p class="text-sm text-gray-500 truncate">${notification.message}</p>
        <p class="text-xs text-gray-400 mt-1">${new Date(notification.created_at).toLocaleString()}</p>
      </div>
    `;

    // Add to the beginning of the list for newest first
    this.notificationsListElement.insertBefore(notificationItem, this.notificationsListElement.firstChild);
    
    // Limit the notifications list to 20 items to prevent excessive DOM growth
    if (this.notificationsListElement.children.length > 20) {
      this.notificationsListElement.removeChild(this.notificationsListElement.lastChild);
    }
  }
}

window.showNotificationToast = (type, title, message, duration) => {
  const event = new CustomEvent('toast:show', {
    detail: { type, title, message, duration }
  })
  document.dispatchEvent(event)
}