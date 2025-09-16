import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selectAll", "consecutivoCheckbox"]

  connect() {
    this.updatePrintButton()
  }

  toggleAll(event) {
    const isChecked = event.target.checked
    
    this.consecutivoCheckboxTargets.forEach(checkbox => {
      checkbox.checked = isChecked
    })
    
    this.updatePrintButton()
  }

  updateSelection() {
    const totalCheckboxes = this.consecutivoCheckboxTargets.length
    const checkedCheckboxes = this.consecutivoCheckboxTargets.filter(cb => cb.checked).length
    
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
    
    this.updatePrintButton()
  }

  updatePrintButton() {
    const checkedCount = this.consecutivoCheckboxTargets.filter(cb => cb.checked).length
    const printButton = document.getElementById('print-labels-btn')
    
    if (checkedCount > 0) {
      if (printButton) {
        printButton.disabled = false
        printButton.classList.remove('opacity-50', 'cursor-not-allowed')
      }
    } else {
      if (printButton) {
        printButton.disabled = true
        printButton.classList.add('opacity-50', 'cursor-not-allowed')
      }
    }
  }

  printLabels() {
    const selectedCheckboxes = this.consecutivoCheckboxTargets.filter(cb => cb.checked)

    if (selectedCheckboxes.length === 0) {
      console.log("No consecutivos selected for printing")
      return
    }

    // Instead of creating a form dynamically, we'll trigger a Turbo form submission
    // by finding and submitting an existing form in the DOM
    
    // Find the hidden form for printing labels
    const printForm = document.getElementById('print-labels-form')
    if (printForm) {
      // Update the hidden fields with selected item IDs
      const itemIdsContainer = document.getElementById('print-item-ids-container')
      if (itemIdsContainer) {
        // Clear existing hidden inputs
        itemIdsContainer.innerHTML = ''
        
        // Add hidden inputs for each selected item
        selectedCheckboxes.forEach(checkbox => {
          const input = document.createElement('input')
          input.type = 'hidden'
          input.name = 'item_ids[]'
          input.value = checkbox.dataset.itemId
          itemIdsContainer.appendChild(input)
        })
      }
      
      // Submit the form via Turbo
      printForm.requestSubmit()
    }

    // Deselect all checkboxes after submission
    this.selectAllTarget.checked = false
    this.selectAllTarget.indeterminate = false
    this.consecutivoCheckboxTargets.forEach(cb => cb.checked = false)
    this.updatePrintButton()
  }

  showPrintConfirmation() {
    console.log("showPrintConfirmation called");
    const selectedCheckboxes = this.consecutivoCheckboxTargets.filter(cb => cb.checked)

    if (selectedCheckboxes.length === 0) {
      console.log("No consecutivos selected for printing")
      return
    }

    // Get the production order ID from the data attribute
    const productionOrderElement = document.querySelector('[data-controller="production-order"]')
    const productionOrderId = productionOrderElement ? productionOrderElement.dataset.orderId : null

    if (!productionOrderId) {
      console.error("No se encontró el ID de la orden de producción")
      return
    }

    // Get selected item IDs
    const itemIds = selectedCheckboxes.map(cb => cb.dataset.itemId)
    console.log("Production Order ID:", productionOrderId);
    console.log("Item IDs:", itemIds);

    // Make a request to show the print confirmation modal
    fetch(`/admin/production_orders/${productionOrderId}/items/show_print_confirmation`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        'Accept': 'text/html'
      },
      body: JSON.stringify({
        item_ids: itemIds.join(',')
      })
    })
    .then(response => {
      console.log("Response status:", response.status);
      if (response.status === 200) {
        return response.text();
      } else {
        throw new Error('Network response was not ok.');
      }
    })
    .then(html => {
      console.log("Response HTML length:", html.length);
      // Remove any existing modal first
      const existingModal = document.getElementById('confirm-print-modal');
      if (existingModal) {
        existingModal.remove();
      }
      
      // Append the modal HTML to the body
      document.body.insertAdjacentHTML('beforeend', html);
      
      // Show the modal by removing the opacity-0 class and pointer-events-none
      setTimeout(() => {
        const modal = document.getElementById('confirm-print-modal');
        if (modal) {
          modal.classList.remove('opacity-0', 'pointer-events-none');
          modal.classList.add('opacity-100');
        }
      }, 10);
    })
    .catch(error => {
      console.error('Error:', error)
    })
  }

  pesarItem(event) {
    const itemId = event.target.dataset.itemId
    console.log(`Pesar consecutivo con ID: ${itemId}`)
    // TODO: Implement weighing functionality
  }

  
}