import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, orderId: String }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    const orderId = this.orderIdValue


    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content,
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: JSON.stringify({ order_id: orderId })
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.json()
    })
    .then(data => {
      if (data.status === "success") {
        const checkbox = this.element.querySelector("input[type='checkbox']")
        checkbox.checked = data.selected
        
        
        // Update the counter and print button state
        this.updateCounter(data.selected_count)
        this.updatePrintButton(data.selected_count)
        
        // Also trigger bulk selection controller to update select all state
        const bulkController = this.application.getControllerForElementAndIdentifier(
          document.querySelector('[data-controller*="bulk-selection"]'),
          'bulk-selection'
        )
        if (bulkController) {
          bulkController.updateSelectAll()
        }
      }
    })
    .catch(error => {
      console.error("Checkbox error:", error)
      // Revert checkbox state on error
      const checkbox = this.element.querySelector("input[type='checkbox']")
      checkbox.checked = !checkbox.checked
    })
  }

  updateCounter(count) {
    const counterElement = document.getElementById('selected-count')
    if (counterElement) {
      counterElement.textContent = count
    }
  }

  updatePrintButton(count) {
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