import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
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
        // Reload the page to update the notification count and styling
        window.location.reload()
      } else {
        console.error('Failed to mark notifications as read')
      }
    })
    .catch(error => {
      console.error('Error:', error)
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
        // Remove the unread styling
        const notificationElement = event.currentTarget.closest('.notification-item')
        if (notificationElement) {
          notificationElement.classList.remove('bg-blue-50')
          const unreadIndicator = notificationElement.querySelector('.unread-indicator')
          if (unreadIndicator) {
            unreadIndicator.remove()
          }
        }
        
        // Update the notification count
        this.updateNotificationCount()
      }
    })
    .catch(error => {
      console.error('Error:', error)
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
}