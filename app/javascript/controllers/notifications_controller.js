import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["indicator"]
  
  connect() {
    this.controllerId = Math.random().toString(36).substring(2, 11)
    
    if (window.activeNotificationsController) {
      return
    }
    
    window.activeNotificationsController = this.controllerId
    
    // Initialize local storage for notifications cache
    this.notificationsCache = this.getNotificationsFromCache() || []
    
    // Check if we have clickable notification elements
    const clickableElements = this.element.querySelectorAll('[data-action*="markAsRead"]')
    
    document.addEventListener('notification:new', this.handleNewNotification.bind(this))
    // Removed toast:show listener to prevent conflict with toast_controller
    // Removed the immediate poll listener that was previously added but is no longer needed
    
    this.createToastContainer()
    
    this.connectToCable()
    
    // Initialize the notifications container element
    this.updateNotificationsContainerElement()
    
    // Set up a periodic check for the notifications container element availability
    this.watchForNotificationsContainer()
    
    // Update UI based on cached read states
    this.syncReadStatusToUI()
  }
  
  disconnect() {
    
    if (window.activeNotificationsController === this.controllerId) {
      window.activeNotificationsController = null
      
      document.removeEventListener('notification:new', this.handleNewNotification.bind(this))
      this.disconnectFromCable()
      
      // Clear the container watcher interval
      if (this.containerWatcher) {
        clearInterval(this.containerWatcher)
        this.containerWatcher = null
      }
    }
  }
  
  connectToCable() {
    const consumer = (window.App && window.App.cable) || window.createConsumer?.('/cable')
    
    if (!consumer) {
      console.error('ActionCable consumer not available');
      return
    }

    this.subscription = consumer.subscriptions.create("NotificationsChannel", {
      received: (data) => {
        if (window.activeNotificationsController !== this.controllerId) {
          return
        }
        
        if (data.type === 'new_notification' && data.notification) {
          console.log('Received new notification via WebSocket:', data.notification);
          
          // Create a unique key to prevent duplicate processing
          const notificationKey = `${data.notification.title}_${data.notification.message}_${data.notification.timestamp || Date.now()}`
          
          // Check if we've already processed this notification recently
          if (this.recentNotifications && this.recentNotifications.has(notificationKey)) {
            console.log('Duplicate notification detected, skipping:', data.notification);
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
          
          // Add the notification to the DOM list immediately
          const tempNotification = {
            ...data.notification,
            id: data.notification.id || `temp_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
            created_at: data.notification.timestamp || new Date().toISOString(),
            read: false
          };
          
          // Add the notification to the DOM list
          this.addNotificationToDOM(tempNotification)
          
          // Show the notification as a toast
          this.showNotificationToast(tempNotification)
          
          // Increment the notification count indicator
          this.incrementNotificationCount()
          
          // Create the notification on the server if not already persistent
          // But only do this after a short delay to avoid overwhelming the server
          setTimeout(() => {
            this.createPersistentNotification(data.notification);
          }, 1000); // Delay the persistent creation by 1 second
        }
      },
      
      connected: () => {
        console.log('Connected to NotificationsChannel');
      },
      
      disconnected: () => {
        console.log('Disconnected from NotificationsChannel');
      },
      
      rejected: () => {
        console.log('Connection to NotificationsChannel rejected');
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
  
  updateNotificationsContainerElement() {
    // The notifications container is the div with class 'max-h-60 overflow-y-auto' inside the dropdown
    this.notificationsContainerElement = this.element.querySelector('.max-h-60.overflow-y-auto');
    
    // If not found in this element, try to find it in the document
    if (!this.notificationsContainerElement) {
      this.notificationsContainerElement = document.querySelector('.max-h-60.overflow-y-auto');
    }
    
    // Try to find by other possible identifiers if the specific class is not available
    if (!this.notificationsContainerElement) {
      // Look for the div that contains notification items inside the dropdown
      const dropdown = this.element.querySelector('[data-dropdown-target="menu"]');
      if (dropdown) {
        this.notificationsContainerElement = dropdown.querySelector('.max-h-60.overflow-y-auto') || 
                                             dropdown.querySelector('.max-h-60') ||
                                             dropdown.querySelector('.overflow-y-auto');
      }
    }
  }
  
  watchForNotificationsContainer() {
    // Periodically check if the notifications container is available
    this.containerWatcher = setInterval(() => {
      this.updateNotificationsContainerElement()
      if (this.notificationsContainerElement) {
        // If notifications container is available, make sure it's populated correctly
        if (this.notificationsContainerElement.children.length <= 1 && this.notificationsCache.length > 0) {
          // If container is available but has no or only placeholder notification, populate it with cached notifications
          this.populateNotificationsFromCache()
        } else if (this.notificationsCache.length > 0) {
          // If container exists and has notifications, make sure new ones are added
          this.ensureAllCachedNotificationsAreDisplayed()
        }
      }
    }, 500) // Check every 500ms
  }
  
  populateNotificationsFromCache() {
    // Clear the container, but keep the "No tienes notificaciones" message if it exists
    const emptyMessage = this.notificationsContainerElement.querySelector('.p-4.text-center.text-gray-500');
    if (emptyMessage) {
      this.notificationsContainerElement.innerHTML = '';
      this.notificationsContainerElement.appendChild(emptyMessage);
    } else {
      this.notificationsContainerElement.innerHTML = '';
    }
    
    // Add all cached notifications to the container
    this.notificationsCache.forEach(notification => {
      this.renderNotificationToElement(notification, this.notificationsContainerElement)
    })
    
    // If there are no notifications, show the empty message
    if (this.notificationsCache.length === 0) {
      this.showEmptyMessage();
    }
  }
  
  ensureAllCachedNotificationsAreDisplayed() {
    // Check if all cached notifications are displayed in the DOM
    this.notificationsCache.forEach(notification => {
      const existingElement = this.notificationsContainerElement.querySelector(`[data-notification-id="${notification.id}"]`)
      if (!existingElement) {
        // If notification is not in DOM, add it at the beginning
        this.renderNotificationToElement(notification, this.notificationsContainerElement)
      }
    })
    
    // Remove empty message if notifications exist
    if (this.notificationsCache.length > 0) {
      const emptyMessage = this.notificationsContainerElement.querySelector('.p-4.text-center.text-gray-500');
      if (emptyMessage) {
        emptyMessage.remove();
      }
    }
    
    // Limit to 20 items
    const notificationItems = this.notificationsContainerElement.querySelectorAll('.notification-item');
    while (notificationItems.length > 20) {
      // Remove the last notification item since we're adding new ones at the beginning
      if (notificationItems.length > 0) {
        notificationItems[notificationItems.length - 1].remove();
      }
    }
  }
  
  formatDate(dateString) {
    try {
      // Handle case where dateString is already a Date object
      if (dateString instanceof Date) {
        return dateString.toLocaleString('es-ES', { 
          day: '2-digit', 
          month: '2-digit', 
          year: 'numeric',
          hour: '2-digit', 
          minute: '2-digit'
        });
      }
      
      // Handle null, undefined, or empty string
      if (!dateString) {
        return 'Fecha desconocida';
      }
      
      // Try to parse the date string using various formats
      let date;
      
      // First, try to parse as ISO string (most common from Rails)
      date = new Date(dateString);
      
      // If it's not a valid date, try parsing without timezone (Rails often sends times in local format)
      if (isNaN(date.getTime())) {
        // Try to handle various common date formats
        // Format 1: "2025-02-10T15:30:00.000Z" (ISO 8601)
        date = new Date(dateString);
        
        // Format 2: "2025-02-10 15:30:00 -0600" (String with timezone offset)
        if (isNaN(date.getTime())) {
          // Remove timezone and treat as local time
          const withoutTz = dateString.replace(/\s+[+-]\d{4}$/, '');
          date = new Date(withoutTz);
        }
        
        // Format 3: "2025-02-10 15:30:00" (String without timezone)
        if (isNaN(date.getTime())) {
          date = new Date(dateString.split(' ')[0] + 'T' + dateString.split(' ')[1]);
        }
      }
      
      // Check if the date is valid
      if (isNaN(date.getTime())) {
        console.warn('Invalid date received:', dateString);
        return 'Fecha desconocida';
      }
      
      // Format the date in a more compatible way
      return date.toLocaleString('es-ES', { 
        day: '2-digit', 
        month: '2-digit', 
        year: 'numeric',
        hour: '2-digit', 
        minute: '2-digit'
      });
    } catch (error) {
      console.error('Error formatting date:', error, 'Input:', dateString);
      return 'Fecha desconocida';
    }
  }

  renderNotificationToElement(notification, containerElement) {
    // Check if notification already exists in the container to prevent duplicates
    const existingNotification = containerElement.querySelector(`[data-notification-id="${notification.id}"]`)
    if (existingNotification) {
      return // Notification already exists in DOM
    }

    // Create a new notification item element matching the original HTML structure
    const notificationItem = document.createElement('div')
    notificationItem.className = `notification-item p-3 border-b border-gray-100 hover:bg-gray-50 ${!notification.read ? 'bg-blue-50' : ''}`
    notificationItem.setAttribute('data-notification-id', notification.id)

    // Create the inner structure matching the original ERB template
    notificationItem.innerHTML = `
      <div class="flex items-start space-x-3">
        <div class="flex-shrink-0">
          <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-5 5v-5zM11 15H6a2 2 0 01-2-2V7a2 2 0 012-2h5m5 0v5a2 2 0 01-2 2H9a2 2 0 01-2-2V7a2 2 0 012-2h5m5 0v5a2 2 0 01-2 2H9a2 2 0 01-2-2V7a2 2 0 012-2h5m0 0V5a2 2 0 00-2-2H9a2 2 0 00-2 2v2"></path>
          </svg>
        </div>
        <div class="flex-1 min-w-0 cursor-pointer" 
             data-action="click->notifications#markAsRead"
             data-notification-id="${notification.id}"
             data-notification-action-url="${notification.action_url || ''}">
          <p class="text-sm font-medium text-gray-900">${notification.title}</p>
          <p class="text-sm text-gray-600">${notification.message}</p>
          <p class="text-xs text-gray-500 mt-1">${this.formatDate(notification.created_at)}</p>
        </div>
        ${!notification.read ? '<div class="flex-shrink-0 unread-indicator"><div class="w-2 h-2 bg-blue-600 rounded-full"></div></div>' : ''}
      </div>
    `

    // Add to the beginning of the container for newest first
    containerElement.insertBefore(notificationItem, containerElement.firstChild)
  }
  
  showEmptyMessage() {
    // Add the empty message if there are no notifications
    if (this.notificationsContainerElement && this.notificationsContainerElement.children.length === 0) {
      const emptyMessage = document.createElement('div');
      emptyMessage.className = 'p-4 text-center text-gray-500';
      emptyMessage.innerHTML = '<p>No tienes notificaciones</p>';
      this.notificationsContainerElement.appendChild(emptyMessage);
    }
  }
  
  addNotificationToCache(notification) {
    // Ensure all required fields are present
    const normalizedNotification = {
      id: notification.id || `temp_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      title: notification.title || 'Título desconocido',
      message: notification.message || 'Mensaje desconocido',
      notification_type: notification.notification_type || 'info',
      created_at: notification.created_at || new Date().toISOString(),
      read: notification.read || false,
      action_url: notification.action_url || ''
    };

    // Check if notification already exists in cache to prevent duplicates
    const existingIndex = this.notificationsCache.findIndex(n => n.id === normalizedNotification.id)
    if (existingIndex !== -1) {
      // Update existing notification
      this.notificationsCache[existingIndex] = { ...this.notificationsCache[existingIndex], ...normalizedNotification }
    } else {
      // Add new notification
      this.notificationsCache.unshift(normalizedNotification)
    }
    
    // Limit cache to 20 items
    if (this.notificationsCache.length > 20) {
      this.notificationsCache = this.notificationsCache.slice(0, 20)
    }
    
    // Save to localStorage
    this.saveNotificationsToCache()
  }
  
  getNotificationsFromCache() {
    try {
      const cached = localStorage.getItem('notificationsCache')
      return cached ? JSON.parse(cached) : []
    } catch (e) {
      console.error('Error reading notifications cache:', e)
      return []
    }
  }
  
  saveNotificationsToCache() {
    try {
      localStorage.setItem('notificationsCache', JSON.stringify(this.notificationsCache))
    } catch (e) {
      console.error('Error saving notifications cache:', e)
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
      console.log('Notification already being processed');
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
      console.error('No clicked element found');
      return
    }
    
    const notificationElement = clickedElement.closest('.notification-item')
    
    if (!notificationElement) {
      console.error('Could not find notification item element');
      return
    }
    
    // Try to get notification ID from either the clicked element or the parent notification element
    let notificationId = clickedElement.dataset.notificationId || notificationElement.dataset.notificationId
    let actionUrl = clickedElement.dataset.notificationActionUrl || notificationElement.dataset.notificationActionUrl
    
    console.log('Marking notification as read:', { notificationId, actionUrl, element: notificationElement })
    
    if (!notificationId) {
      console.error('No notification ID found');
      return
    }
    
    // Small delay to ensure DOM is stable and avoid race conditions
    setTimeout(() => {
      const url = `/admin/notifications/${notificationId}/mark_read`
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
      
      if (!csrfToken) {
        console.error('CSRF token not found');
        return
      }
      
      console.log('Attempting to mark notification as read with URL:', url);
      this.performMarkAsRead(url, csrfToken, notificationElement, actionUrl, event, processingElement)
    }, 50)
  }
  
  performMarkAsRead(url, csrfToken, notificationElement, actionUrl, event, processingElement) {
    // Get the notification ID from the element
    const notificationId = notificationElement.dataset.notificationId;
    
    console.log('Performing mark as read request:', { url, notificationId });
    
    // Check if this is a temporary notification (has ID starting with 'temp_')
    if (notificationId && notificationId.startsWith('temp_')) {
      // This is a temporary notification, just update visual state and cache
      console.log('Temporary notification, updating visual state only');
      
      notificationElement.classList.remove('bg-blue-50')
      const unreadIndicator = notificationElement.querySelector('.unread-indicator')
      if (unreadIndicator) {
        unreadIndicator.remove()
      }
      
      // Update the notification in the cache to mark it as read
      this.updateNotificationInCache(notificationId, { read: true });
      
      this.updateNotificationCount()
      
      if (actionUrl && actionUrl.trim() !== '' && !event.ctrlKey && !event.metaKey) {
        setTimeout(() => {
          window.location.href = actionUrl
        }, 800)
      }
      
      // Clean up processing flag
      if (processingElement) {
        delete processingElement.dataset.processing
      }
      
      return; // Exit early for temporary notifications
    }
    
    // This is a persistent notification, make the server request
    fetch(url, {
      method: 'PATCH',
      headers: {
        'X-CSRF-Token': csrfToken,
        'Content-Type': 'application/json',
      }
    })
    .then(async response => {
      console.log('Response received:', response.status);
      
      if (response.ok) {
        console.log('Notification marked as read successfully');
        
        // Remove visual indicators of unread status
        notificationElement.classList.remove('bg-blue-50')
        const unreadIndicator = notificationElement.querySelector('.unread-indicator')
        if (unreadIndicator) {
          unreadIndicator.remove()
        }
        
        // Update the notification in the cache to mark it as read
        this.updateNotificationInCache(notificationId, { read: true });
        
        this.updateNotificationCount()
        
        if (actionUrl && actionUrl.trim() !== '' && !event.ctrlKey && !event.metaKey) {
          setTimeout(() => {
            window.location.href = actionUrl
          }, 800)
        }
      } else {
        // Even if server request failed, update visual state and cache
        console.warn('Server request failed, updating visual state only:', response.status);
        
        // Update visual indicators anyway
        notificationElement.classList.remove('bg-blue-50')
        const unreadIndicator = notificationElement.querySelector('.unread-indicator')
        if (unreadIndicator) {
          unreadIndicator.remove()
        }
        
        // Update the notification in the cache to mark it as read
        this.updateNotificationInCache(notificationId, { read: true });
        
        this.updateNotificationCount()
        
        if (actionUrl && actionUrl.trim() !== '' && !event.ctrlKey && !event.metaKey) {
          setTimeout(() => {
            window.location.href = actionUrl
          }, 800)
        }
      }
      
      // Clean up processing flag
      if (processingElement) {
        delete processingElement.dataset.processing
      }
    })
    .catch(error => {
      console.error('Network error marking notification as read:', error);
      
      // Update visual state and cache on network error
      notificationElement.classList.remove('bg-blue-50')
      const unreadIndicator = notificationElement.querySelector('.unread-indicator')
      if (unreadIndicator) {
        unreadIndicator.remove()
      }
      
      // Update the notification in the cache to mark it as read
      this.updateNotificationInCache(notificationId, { read: true });
      
      this.updateNotificationCount()
      
      // Clean up processing flag
      if (processingElement) {
        delete processingElement.dataset.processing
      }
    });
  }
  
  async createPersistentNotification(notificationData) {
    try {
      // Check if we're authenticated and have a current user
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
      
      // Attempt to create the notification via the API
      const response = await fetch('/admin/notifications', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify({
          notification: {
            title: notificationData.title,
            message: notificationData.message,
            notification_type: notificationData.type || 'system',
            action_url: notificationData.action_url || null
          }
        })
      });
      
      if (response.ok) {
        const result = await response.json();
        console.log('Persistent notification created:', result);
        
        // Update our cache with the real ID from the server
        if (result.notification && result.notification.id) {
          // Find the temporary notification in our cache and update it with the real ID
          const tempIndex = this.notificationsCache.findIndex(n => 
            n.title === notificationData.title && 
            n.message === notificationData.message &&
            n.created_at === (notificationData.timestamp || n.created_at)
          );
          
          if (tempIndex !== -1) {
            // Update the notification in cache with the real server ID
            const updatedNotification = { ...this.notificationsCache[tempIndex], id: result.notification.id };
            this.notificationsCache[tempIndex] = updatedNotification;
            this.saveNotificationsToCache();
            
            // Update the DOM to use the real ID
            this.updateNotificationIdInDOM(this.notificationsCache[tempIndex].id, result.notification.id);
          }
        }
        
        return result.notification; // Return the server-created notification with ID
      } else {
        console.error('Failed to create persistent notification:', response.status);
        // If creation failed, return null so we use a temporary notification
        return null;
      }
    } catch (error) {
      console.error('Error creating persistent notification:', error);
      // If there was a network error, return null so we use a temporary notification
      return null;
    }
  }
  
  updateNotificationIdInDOM(oldId, newId) {
    // Find the notification element with the old ID and update it to use the new ID
    const notificationElement = document.querySelector(`[data-notification-id="${oldId}"]`);
    if (notificationElement) {
      notificationElement.setAttribute('data-notification-id', newId);
      
      // Update the data-action attribute if it contains the old ID
      const actionAttr = notificationElement.getAttribute('data-action');
      if (actionAttr) {
        const updatedAction = actionAttr.replace(`data-notification-id-param="${oldId}"`, `data-notification-id-param="${newId}"`);
        notificationElement.setAttribute('data-action', updatedAction);
      }
    }
  }
  
  syncReadStatusToUI() {
    // This function syncs read status from our local cache to the UI
    // It will be called on connect to ensure visual consistency
    if (this.notificationsContainerElement) {
      // Loop through all notification elements in the container
      const notificationElements = this.notificationsContainerElement.querySelectorAll('.notification-item');
      
      notificationElements.forEach(element => {
        const notificationId = element.dataset.notificationId;
        
        if (notificationId) {
          // Find the notification in our cache
          const cachedNotification = this.notificationsCache.find(n => n.id === notificationId);
          
          if (cachedNotification && cachedNotification.read) {
            // If the notification is marked as read in cache, update the UI
            element.classList.remove('bg-blue-50');
            const unreadIndicator = element.querySelector('.unread-indicator');
            if (unreadIndicator) {
              unreadIndicator.remove();
            }
          }
        }
      });
      
      // Update the notification count based on cached unread notifications
      this.updateNotificationCountFromCache();
    }
  }
  
  updateNotificationCountFromCache() {
    // Calculate unread notifications from cache
    const unreadCount = this.notificationsCache.filter(n => !n.read).length;
    
    // Update the indicator element
    const indicatorContainer = this.indicatorTarget;
    if (!indicatorContainer) return;

    let countElement = indicatorContainer.querySelector('.notification-count');

    if (unreadCount > 0) {
      if (!countElement) {
        countElement = document.createElement('span');
        countElement.className = 'notification-count inline-flex items-center justify-center px-2 py-1 text-xs font-bold leading-none text-red-100 bg-red-600 rounded-full';
        indicatorContainer.appendChild(countElement);
      }
      countElement.textContent = unreadCount > 99 ? "99+" : unreadCount.toString();
    } else {
      if (countElement) {
        countElement.remove();
      }
    }
  }
  
  updateNotificationInCache(notificationId, updates) {
    const index = this.notificationsCache.findIndex(n => n.id == notificationId);
    if (index !== -1) {
      this.notificationsCache[index] = { ...this.notificationsCache[index], ...updates };
      this.saveNotificationsToCache();
    }
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
    // Add to the local cache
    this.addNotificationToCache(notification)
    
    // Update the reference to the notifications container element
    this.updateNotificationsContainerElement()
    
    // If the notifications container element exists, add the notification to it immediately
    if (this.notificationsContainerElement) {
      this.renderNotificationToElement(notification, this.notificationsContainerElement)
      
      // Remove empty message if it exists
      const emptyMessage = this.notificationsContainerElement.querySelector('.p-4.text-center.text-gray-500');
      if (emptyMessage) {
        emptyMessage.remove();
      }
      
      // Limit the notifications container to 20 items to prevent excessive DOM growth
      const notificationItems = this.notificationsContainerElement.querySelectorAll('.notification-item');
      while (notificationItems.length > 20) {
        // Remove the last notification item since we're adding new ones at the beginning
        if (notificationItems.length > 0) {
          notificationItems[notificationItems.length - 1].remove();
        }
      }
    }
  }
}

window.showNotificationToast = (type, title, message, duration) => {
  const event = new CustomEvent('toast:show', {
    detail: { type, title, message, duration }
  })
  document.dispatchEvent(event)
}