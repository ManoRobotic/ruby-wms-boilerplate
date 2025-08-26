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
}