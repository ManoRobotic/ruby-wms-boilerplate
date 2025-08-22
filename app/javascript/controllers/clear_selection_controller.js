import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  clearAll(event) {
    event.preventDefault()
    
    // Get current selected count from the counter
    const counterElement = document.getElementById('selected-count')
    const currentCount = counterElement ? parseInt(counterElement.textContent) : 0
    
    if (currentCount === 0) {
      alert('No hay órdenes seleccionadas para limpiar.')
      return
    }

    // Confirm action - show total count including other pages
    if (!confirm(`¿Estás seguro de que quieres limpiar TODAS las selecciones? (${currentCount} órdenes en total, incluyendo otras páginas)`)) {
      return
    }
    
    // Send request to clear ALL selections from server
    fetch('/admin/production_orders/clear_all_selections', {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content,
        "Accept": "application/json"
      }
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.json()
    })
    .then(data => {
      if (data.status === "success") {
        // Clear all checkboxes on current page
        document.querySelectorAll('.order-checkbox').forEach(checkbox => {
          checkbox.checked = false
        })
        
        // Clear master checkbox
        const selectAllCheckbox = document.getElementById('select-all-checkbox')
        if (selectAllCheckbox) {
          selectAllCheckbox.checked = false
          selectAllCheckbox.indeterminate = false
        }
        
        // Update counter and buttons
        this.updateCounter(0)
        this.updateButtons(0)
        
        alert(`✅ ${data.message}`)
      }
    })
    .catch(error => {
      console.error("Error:", error)
      alert('Error al limpiar la selección. Por favor intenta de nuevo.')
    })
  }

  updateCounter(count) {
    const counterElement = document.getElementById('selected-count')
    if (counterElement) {
      counterElement.textContent = count
    }
  }

  updateButtons(count) {
    const printButton = document.getElementById('print-selection-btn')
    const clearButton = document.getElementById('clear-selection-btn')
    
    if (count > 0) {
      if (printButton) {
        printButton.disabled = false
        printButton.classList.remove('opacity-50', 'cursor-not-allowed')
      }
      if (clearButton) {
        clearButton.disabled = false
        clearButton.classList.remove('opacity-50', 'cursor-not-allowed')
      }
    } else {
      if (printButton) {
        printButton.disabled = true
        printButton.classList.add('opacity-50', 'cursor-not-allowed')
      }
      if (clearButton) {
        clearButton.disabled = true
        clearButton.classList.add('opacity-50', 'cursor-not-allowed')
      }
    }
  }
}