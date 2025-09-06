import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selectAll", "consecutivoCheckbox"]

  connect() {
    this.updatePrintButton()
    
    // Add event listener for edit buttons
    document.addEventListener('click', (event) => {
      if (event.target.matches('[data-dialog-target="edit-consecutivo-modal"]') || 
          event.target.closest('[data-dialog-target="edit-consecutivo-modal"]')) {
        const editButton = event.target.closest('[data-dialog-target="edit-consecutivo-modal"]')
        const itemId = editButton.dataset.itemId
        this.loadEditForm(itemId)
      }
    })
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

  pesarItem(event) {
    const itemId = event.target.dataset.itemId
    console.log(`Pesar consecutivo con ID: ${itemId}`)
    // TODO: Implement weighing functionality
  }

  loadEditForm(itemId) {
    // Find the checkbox for this item to get the production order ID
    const checkbox = this.consecutivoCheckboxTargets.find(cb => cb.dataset.itemId === itemId)
    if (!checkbox) {
      console.error("Could not find checkbox for item ID:", itemId)
      return
    }

    const productionOrderId = checkbox.dataset.productionOrderId
    console.log("Loading edit form for item:", itemId, "in production order:", productionOrderId)
    
    // Instead of AJAX, we'll use Turbo navigation to load the form into the Turbo frame
    // We need to navigate to the edit URL which will load the form into the turbo-frame
    const editUrl = `/admin/production_orders/${productionOrderId}/items/${itemId}/edit`
    
    // Find the Turbo frame and navigate to the edit URL
    const turboFrame = document.getElementById('edit-consecutivo-form')
    if (turboFrame) {
      turboFrame.src = editUrl
    }
  }
}