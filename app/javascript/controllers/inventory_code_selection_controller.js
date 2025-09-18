import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selectAll", "inventoryCodeCheckbox"]

  connect() {
    this.restoreSelection()
    this.updatePrintButton()
    
    // Listen for custom confirm print event
    this.element.addEventListener('confirm-print-selected', this.handleConfirmPrint.bind(this))
  }

  handleConfirmPrint(event) {
    this.confirmPrint()
  }

  toggleAll(event) {
    const isChecked = event.target.checked
    
    this.inventoryCodeCheckboxTargets.forEach(checkbox => {
      checkbox.checked = isChecked
    })
    
    this.updateSelection()
  }

  updateSelection() {
    const totalCheckboxes = this.inventoryCodeCheckboxTargets.length
    const checkedCheckboxes = this.inventoryCodeCheckboxTargets.filter(cb => cb.checked).length
    
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
    
    this.saveSelection()
    this.updatePrintButton()
  }

  updatePrintButton() {
    const selectedIds = this.getSelectedIdsFromStorage()
    const checkedCount = selectedIds.length
    const printButton = document.getElementById('print-selection-btn')
    const clearButton = document.getElementById('clear-selection-btn')
    
    if (checkedCount > 0) {
      if (printButton) {
        printButton.disabled = false
        printButton.classList.remove('opacity-50', 'cursor-not-allowed')
      }
      if (clearButton) {
        clearButton.disabled = false
        clearButton.classList.remove('opacity-50', 'cursor-not-allowed')
      }
      
      // Update counter
      const counterElement = document.getElementById('selected-count')
      if (counterElement) {
        counterElement.textContent = checkedCount
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
      
      // Update counter
      const counterElement = document.getElementById('selected-count')
      if (counterElement) {
        counterElement.textContent = '0'
      }
    }
  }

  printSelected() {
    const selectedIds = this.getSelectedIdsFromStorage()
    
    if (selectedIds.length === 0) {
      return
    }

    // Update the modal content with the count of selected items
    const modalTitle = document.querySelector('[data-dialog="confirm-print-modal"] .flex.shrink-0.items-center');
    const modalMessage = document.querySelector('[data-dialog="confirm-print-modal"] .text-slate-700');
    
    if (modalTitle) {
      modalTitle.textContent = "Confirmar Impresión";
    }
    
    if (modalMessage) {
      modalMessage.textContent = `¿Está seguro que desea imprimir ${selectedIds.length} etiquetas seleccionadas?`;
    }

    // Open the confirm print modal by dispatching a global event with the selected IDs
    const openEvent = new CustomEvent('open-confirm-print-modal', {
      detail: { 
        selectedCount: selectedIds.length,
        selectedIds: selectedIds
      }
    });
    document.dispatchEvent(openEvent);
  }

  confirmPrint() {
    console.log("confirmPrint method called");
    const hiddenInput = document.getElementById('confirm-print-item-ids');
    console.log("Hidden input element:", hiddenInput);
    if (hiddenInput) {
      const selectedIds = hiddenInput.value.split(',').filter(id => id.length > 0);
      console.log("Códigos de inventario a imprimir (IDs):", selectedIds);
      
      // Close the modal
      const modalElement = document.querySelector('[data-dialog="confirm-print-modal"]').closest('[data-controller="dialog"]');
      console.log("Modal element:", modalElement);
      if (modalElement) {
        const dialogController = this.application.getControllerForElementAndIdentifier(modalElement, 'dialog');
        console.log("Dialog controller:", dialogController);
        if (dialogController) {
          dialogController.close("confirm-print-modal");
        }
      }
    }
  }

  saveSelection() {
    let selectedIds = this.getSelectedIdsFromStorage()
    const currentPageIds = this.inventoryCodeCheckboxTargets.map(cb => cb.dataset.codeId)

    // Remove IDs from the current page from the stored selection
    selectedIds = selectedIds.filter(id => !currentPageIds.includes(id))

    // Add the newly selected IDs from the current page
    const newlySelectedIds = this.inventoryCodeCheckboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.dataset.codeId)
    
    selectedIds.push(...newlySelectedIds)
    
    sessionStorage.setItem("selectedInventoryCodes", JSON.stringify([...new Set(selectedIds)]))
  }

  restoreSelection() {
    const selectedIds = this.getSelectedIdsFromStorage()
    
    this.inventoryCodeCheckboxTargets.forEach(checkbox => {
      if (selectedIds.includes(checkbox.dataset.codeId)) {
        checkbox.checked = true
      }
    })

    this.updateSelection()
  }

  clearSelection() {
    sessionStorage.removeItem("selectedInventoryCodes")
    this.inventoryCodeCheckboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
    this.updateSelection()
  }

  getSelectedIdsFromStorage() {
    return JSON.parse(sessionStorage.getItem("selectedInventoryCodes")) || []
  }
}