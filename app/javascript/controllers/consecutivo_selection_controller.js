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
    const pdfButton = document.getElementById('download-pdf-btn')
    const csvButton = document.getElementById('download-csv-btn')

    const hasSelection = checkedCount > 0

    ;[printButton, pdfButton, csvButton].forEach(btn => {
      if (!btn) return
      btn.disabled = !hasSelection
      btn.classList.toggle('opacity-50', !hasSelection)
      btn.classList.toggle('cursor-not-allowed', !hasSelection)
    })
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

  // ----------- PDF Download -----------
  downloadPdf(event) {
    const selectedCheckboxes = this.consecutivoCheckboxTargets.filter(cb => cb.checked)
    if (selectedCheckboxes.length === 0) return

    const btn = event.currentTarget
    const productionOrderId = btn.dataset.productionOrderId

    const params = new URLSearchParams()
    selectedCheckboxes.forEach(cb => params.append('item_ids[]', cb.dataset.itemId))

    const url = `/admin/production_orders/${productionOrderId}/print_consecutivos.pdf?${params.toString()}`
    window.location.href = url
  }

  // ----------- CSV Download -----------
  downloadCsv(event) {
    const selectedCheckboxes = this.consecutivoCheckboxTargets.filter(cb => cb.checked)
    if (selectedCheckboxes.length === 0) return

    const btn = event.currentTarget
    const orderNumber = btn.dataset.orderNumber

    const headers = ['Clave', 'Folio', 'Clave Producto', 'Peso Bruto (kg)', 'Peso Neto (kg)', 'Metros', 'Micras', 'Ancho (mm)']
    const rows = selectedCheckboxes.map(cb => [
      cb.dataset.noOpro || '',
      cb.dataset.folio || '',
      cb.dataset.claveProducto || '',
      cb.dataset.pesoBruto || '',
      cb.dataset.pesoNeto || '',
      cb.dataset.metrosLineales || '',
      cb.dataset.micras || '',
      cb.dataset.anchoMm || ''
    ])

    const csvContent = [headers, ...rows]
      .map(row => row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(','))
      .join('\n')

    // BOM for Excel UTF-8 detection
    const blob = new Blob(['\uFEFF' + csvContent], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = `consecutivos_${orderNumber || 'orden'}.csv`
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    URL.revokeObjectURL(url)
  }

  pesarItem(event) {
    const itemId = event.target.dataset.itemId
    console.log(`Pesar consecutivo con ID: ${itemId}`)
    // TODO: Implement weighing functionality
  }

  
}