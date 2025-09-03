import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  clearAll(event) {
    event.preventDefault()
    
    if (!confirm("¿Estás seguro de que quieres limpiar toda la selección?")) {
      return
    }
    
    // Send request to server to clear all selections
    fetch('/admin/inventory_codes/clear_selection', {
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
        // Clear all checkboxes in the UI
        document.querySelectorAll('.order-checkbox').forEach(checkbox => {
          checkbox.checked = false
        })
        
        // Update counter to 0
        const counterElement = document.getElementById('selected-count')
        if (counterElement) {
          counterElement.textContent = '0'
        }
        
        // Disable print and clear buttons
        const printButton = document.getElementById('print-selection-btn')
        const clearButton = document.getElementById('clear-selection-btn')
        
        if (printButton) {
          printButton.disabled = true
          printButton.classList.add('opacity-50', 'cursor-not-allowed')
        }
        
        if (clearButton) {
          clearButton.disabled = true
          clearButton.classList.add('opacity-50', 'cursor-not-allowed')
        }
        
        // Reset select all checkbox
        const selectAllCheckbox = document.querySelector('[data-bulk-selection-target="selectAll"]')
        if (selectAllCheckbox) {
          selectAllCheckbox.checked = false
          selectAllCheckbox.indeterminate = false
        }
        
        alert(`✅ SELECCIÓN LIMPIADA\n\n${data.message}`)
      } else {
        alert(`❌ ERROR\n\n${data.message}`)
      }
    })
    .catch(error => {
      console.error('Error:', error)
      alert(`❌ ERROR DE COMUNICACIÓN\n\nNo se pudo conectar con el servidor.\n\n🔧 Detalles: ${error.message}`)
    })
  }
}