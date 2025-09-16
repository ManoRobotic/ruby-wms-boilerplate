import { Controller } from "@hotwired/stimulus"

// Conectar todos los botones de cierre de toasts
document.addEventListener('DOMContentLoaded', function() {
  // Delegar eventos para botones de cierre de toasts
  document.addEventListener('click', function(event) {
    if (event.target.closest('[data-dismiss-target]')) {
      const closeButton = event.target.closest('[data-dismiss-target]')
      const toast = closeButton.closest('[role="alert"]')
      if (toast) {
        // Agregar animación de salida
        toast.style.transition = 'opacity 0.3s ease-out'
        toast.style.opacity = '0'
        
        // Remover el elemento después de la transición
        setTimeout(() => {
          if (toast.parentNode) {
            toast.parentNode.removeChild(toast)
          }
        }, 300)
      }
    }
  })
  
  // Auto-dismiss toasts después de 5 segundos
  setTimeout(() => {
    const toasts = document.querySelectorAll('[role="alert"]')
    toasts.forEach(toast => {
      if (toast.parentNode) {
        // Agregar animación de salida
        toast.style.transition = 'opacity 0.3s ease-out'
        toast.style.opacity = '0'
        
        // Remover el elemento después de la transición
        setTimeout(() => {
          if (toast.parentNode) {
            toast.parentNode.removeChild(toast)
          }
        }, 300)
      }
    })
  }, 5000)
})