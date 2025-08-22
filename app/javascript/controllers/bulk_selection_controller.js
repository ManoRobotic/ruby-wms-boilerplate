import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selectAll", "orderCheckbox"]

  connect() {
    this.loadCorrectCounter()
  }

  toggleAll(event) {
    const isChecked = event.target.checked
    const orderIds = this.orderCheckboxTargets.map(cb => cb.dataset.orderId)
    const action = isChecked ? 'select_all' : 'deselect_all'
    
    // Update UI immediately for better UX
    this.orderCheckboxTargets.forEach(checkbox => {
      checkbox.checked = isChecked
    })
    
    // Send request to server to update session
    fetch('/admin/production_orders/bulk_toggle_selection', {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content,
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: JSON.stringify({ 
        order_ids: orderIds,
        action: action
      })
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.json()
    })
    .then(data => {
      if (data.status === "success") {
        // Update with server count, not local checkboxes
        this.updateCounter(data.selected_count)
        this.updatePrintButtonFromServerCount(data.selected_count)
      }
    })
    .catch(error => {
      console.error("Error:", error)
      // Revert UI changes on error
      this.orderCheckboxTargets.forEach(checkbox => {
        checkbox.checked = !isChecked
      })
      this.selectAllTarget.checked = !isChecked
    })
  }

  updateSelectAll() {
    const totalCheckboxes = this.orderCheckboxTargets.length
    const checkedCheckboxes = this.orderCheckboxTargets.filter(cb => cb.checked).length
    
    if (checkedCheckboxes === 0) {
      this.selectAllTarget.checked = false
      this.selectAllTarget.indeterminate = false
    } else if (checkedCheckboxes === totalCheckboxes) {
      this.selectAllTarget.checked = true
      this.selectAllTarget.indeterminate = false
    } else {
      this.selectAllTarget.checked = false
      this.selectAllTarget.indeterminate = true
    }
    
    // Don't update counter here - it should only be updated from server
    // Only update button state based on visible checkboxes when needed
  }

  updateCounterFromCheckboxes() {
    const checkedCount = this.orderCheckboxTargets.filter(cb => cb.checked).length
    this.updateCounter(checkedCount)
  }

  updatePrintButton() {
    const checkedCount = this.orderCheckboxTargets.filter(cb => cb.checked).length
    this.updatePrintButtonFromServerCount(checkedCount)
  }

  updatePrintButtonFromServerCount(count) {
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

  updateSelectAllState() {
    setTimeout(() => {
      this.updateSelectAll()
    }, 100)
  }

  loadCorrectCounter() {
    
    // Load the correct counter and selections from server when page loads
    fetch('/admin/production_orders/selected_orders_data', {
      method: "GET",
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
        // Update counter with server value
        this.updateCounter(data.count)
        this.updatePrintButtonFromServerCount(data.count)
        
        // Mark checkboxes as selected based on server data
        if (data.data && data.data.length > 0) {
          const selectedIds = data.data.map(order => order.id)
          
          this.orderCheckboxTargets.forEach(checkbox => {
            const orderId = checkbox.dataset.orderId
            if (selectedIds.includes(orderId)) {
              checkbox.checked = true
            } else {
              checkbox.checked = false
            }
          })
          
          // Update select all state based on visible checkboxes
          this.updateSelectAll()
        } else {
          // Clear all checkboxes if no selections
          this.orderCheckboxTargets.forEach(checkbox => {
            checkbox.checked = false
          })
          this.updateSelectAll()
        }
      }
    })
    .catch(error => {
      console.error("Error loading counter:", error)
    })
  }

  updateCounter(count) {
    const counterElement = document.getElementById('selected-count')
    if (counterElement) {
      counterElement.textContent = count
    }
  }

}