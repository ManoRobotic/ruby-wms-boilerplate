import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selectAll", "inventoryCodeCheckbox"]

  connect() {
    this.restoreSelection()
    this.updatePrintButton()
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

    // You can now use these IDs to fetch the data from the server
    // and generate the labels to print.
    console.log("Códigos de inventario a imprimir (IDs):", selectedIds)
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