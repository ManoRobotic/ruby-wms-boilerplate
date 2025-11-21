import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["confirmButton"]
  
  connect() {
    console.log("Confirm print modal controller connected")
    // Listen for the open event
    this.openModalHandler = this.handleOpenModal.bind(this)
    document.addEventListener('open-confirm-print-modal', this.openModalHandler)
  }
  
  handleOpenModal(event) {
    console.log("Open confirm print modal event received", event.detail)
    // Store the selected IDs for later use
    this.selectedIds = event.detail.selectedIds
    
    // Update the message with the selected count
    const modalMessage = this.element.querySelector('[data-dialog="confirm-print-modal"] .text-slate-700');
    if (modalMessage) {
      modalMessage.textContent = `¿Está seguro que desea imprimir ${event.detail.selectedCount} etiquetas seleccionadas?`;
    }
    
    // Open the modal using the dialog controller
    this.openModal()
  }
  
  openModal() {
    // Dispatch the dialog:open event that the dialog controller listens for
    const openEvent = new CustomEvent('dialog:open')
    this.element.dispatchEvent(openEvent)
  }
  
  confirmPrint() {
    console.log("Confirm print button clicked", this.selectedIds);

    if (this.selectedIds && this.selectedIds.length > 0) {
      fetch('/admin/inventory_codes/print_selected_labels', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ selected_ids: this.selectedIds })
      })
      .then(response => response.json())
      .then(data => {
        if(data.print_success) {
          alert(data.message);
        } else {
          alert(`Error: ${data.message}`);
        }
      })
      .catch(error => {
        console.error('Error printing labels:', error);
        alert('An unexpected error occurred while trying to print.');
      });
    }

    this.closeModal();
  }
  
  closeModal() {
    // Dispatch the dialog:close event that the dialog controller listens for
    const closeEvent = new CustomEvent('dialog:close')
    this.element.dispatchEvent(closeEvent)
  }
  
  disconnect() {
    // Clean up event listener
    if (this.openModalHandler) {
      document.removeEventListener('open-confirm-print-modal', this.openModalHandler)
    }
  }
}