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

    const labels = selectedCheckboxes.map(checkbox => {
      const folioFull = checkbox.dataset.folio
      // Extract number after the dash (e.g., "FE-CR-044321-2" -> "2")
      const name = folioFull ? folioFull.split('-').pop() : ''
      
      return {
        name: name,
        lote: checkbox.dataset.lote || '',
        clave_producto: checkbox.dataset.claveProducto || '',
        peso_bruto: checkbox.dataset.pesoBruto || '',
        peso_neto: checkbox.dataset.pesoNeto || '',
        metro_lineales: checkbox.dataset.metrosLineales || '',
        cliente: checkbox.dataset.cliente || '',
        numero_de_orden: checkbox.dataset.noOpro || ''
      }
    })

    console.log("Etiquetas a imprimir:", labels)
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
    
    // Show loading indicator
    const modalContainer = document.getElementById('edit-consecutivo-form-container')
    if (modalContainer) {
      modalContainer.innerHTML = `
        <div class="relative border-t border-slate-200 py-2">
          <div class="text-center py-8">
            <div class="inline-block animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-emerald-500"></div>
            <p class="mt-2 text-sm text-gray-500">Cargando formulario...</p>
          </div>
        </div>
      `
    }

    // Load the form via AJAX using the correct route
    // Note: The route uses 'items' instead of 'production_order_items' due to the path alias in routes.rb
    fetch(`/admin/production_orders/${productionOrderId}/items/${itemId}/edit.js`, {
      headers: {
        'X-Requested-With': 'XMLHttpRequest',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'Accept': 'text/javascript'
      }
    })
    .then(response => {
      console.log("Received response from server:", response.status, response.statusText)
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.text()
    })
    .then(html => {
      console.log("Received HTML content for form")
      if (modalContainer) {
        modalContainer.innerHTML = `
          <div class="relative border-t border-slate-200 py-2">
            ${html}
          </div>
        `
      }
    })
    .catch(error => {
      console.error('Error loading edit form:', error)
      if (modalContainer) {
        modalContainer.innerHTML = `
          <div class="relative border-t border-slate-200 py-2">
            <div class="text-center py-8">
              <p class="text-red-500">Error al cargar el formulario. Por favor, intente de nuevo.</p>
              <p class="text-sm text-gray-500 mt-2">Error: ${error.message}</p>
            </div>
          </div>
        `
      }
    })
  }
}