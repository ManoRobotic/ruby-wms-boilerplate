import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="table"
export default class extends Controller {
  static targets = ["row", "checkbox", "selectAll", "bulkActions", "searchInput"]
  static classes = ["selected", "hoverable"]
  static values = { 
    sortable: { type: Boolean, default: false },
    searchable: { type: Boolean, default: false }
  }

  connect() {
    this.selectedRows = new Set()
    
    if (this.searchableValue && this.hasSearchInputTarget) {
      this.setupSearch()
    }
    
    if (this.sortableValue) {
      this.setupSorting()
    }
    
    this.updateBulkActions()
  }

  setupSearch() {
    this.searchInputTarget.addEventListener('input', this.debounce(this.search.bind(this), 300))
  }

  setupSorting() {
    const headers = this.element.querySelectorAll('th[data-sortable]')
    headers.forEach(header => {
      header.style.cursor = 'pointer'
      header.addEventListener('click', this.sort.bind(this))
    })
  }

  search(event) {
    const query = event.target.value.toLowerCase()
    
    this.rowTargets.forEach(row => {
      const text = row.textContent.toLowerCase()
      if (text.includes(query)) {
        row.style.display = ''
      } else {
        row.style.display = 'none'
      }
    })
  }

  sort(event) {
    const header = event.target
    const column = header.dataset.sortable
    const currentDirection = header.dataset.sortDirection || 'asc'
    const newDirection = currentDirection === 'asc' ? 'desc' : 'asc'
    
    // Clear other sort indicators
    this.element.querySelectorAll('th[data-sortable]').forEach(h => {
      h.classList.remove('sort-asc', 'sort-desc')  
      delete h.dataset.sortDirection
    })
    
    // Set new sort direction
    header.dataset.sortDirection = newDirection
    header.classList.add(`sort-${newDirection}`)
    
    // Sort rows
    this.sortRows(column, newDirection)
  }

  sortRows(column, direction) {
    const tbody = this.element.querySelector('tbody')
    const rows = Array.from(this.rowTargets)
    
    rows.sort((a, b) => {
      const aValue = this.getCellValue(a, column)
      const bValue = this.getCellValue(b, column)
      
      let comparison = 0
      if (aValue < bValue) comparison = -1
      if (aValue > bValue) comparison = 1
      
      return direction === 'asc' ? comparison : -comparison
    })
    
    // Reorder DOM elements
    rows.forEach(row => tbody.appendChild(row))
  }

  getCellValue(row, column) {
    const cell = row.querySelector(`td[data-column="${column}"]`)
    return cell ? cell.textContent.trim() : ''
  }

  toggleRow(event) {
    const checkbox = event.target
    const row = checkbox.closest('[data-table-target="row"]')
    
    if (checkbox.checked) {
      this.selectRow(row)
    } else {
      this.deselectRow(row)
    }
    
    this.updateSelectAllState()
    this.updateBulkActions()
  }

  selectRow(row) {
    row.classList.add(this.selectedClass)
    this.selectedRows.add(row)
  }

  deselectRow(row) {
    row.classList.remove(this.selectedClass)
    this.selectedRows.delete(row)
  }

  toggleAll(event) {
    const selectAll = event.target
    const checkboxes = this.checkboxTargets
    
    checkboxes.forEach(checkbox => {
      checkbox.checked = selectAll.checked
      const row = checkbox.closest('[data-table-target="row"]')
      
      if (selectAll.checked) {
        this.selectRow(row)
      } else {
        this.deselectRow(row)
      }
    })
    
    this.updateBulkActions()
  }

  updateSelectAllState() {
    if (!this.hasSelectAllTarget) return
    
    const checkboxes = this.checkboxTargets
    const checkedBoxes = checkboxes.filter(cb => cb.checked)
    
    this.selectAllTarget.checked = checkedBoxes.length === checkboxes.length
    this.selectAllTarget.indeterminate = checkedBoxes.length > 0 && checkedBoxes.length < checkboxes.length
  }

  updateBulkActions() {
    if (!this.hasBulkActionsTarget) return
    
    const selectedCount = this.selectedRows.size
    
    if (selectedCount > 0) {
      this.bulkActionsTarget.style.display = 'block'
      this.updateBulkActionText(selectedCount)
    } else {
      this.bulkActionsTarget.style.display = 'none'
    }
  }

  updateBulkActionText(count) {
    const countElement = this.bulkActionsTarget.querySelector('[data-count]')
    if (countElement) {
      countElement.textContent = count
    }
  }

  getSelectedIds() {
    return Array.from(this.selectedRows).map(row => {
      const checkbox = row.querySelector('input[type="checkbox"]')
      return checkbox ? checkbox.value : null
    }).filter(Boolean)
  }

  clearSelection() {
    this.selectedRows.forEach(row => this.deselectRow(row))
    this.selectedRows.clear()
    
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
    
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = false
      this.selectAllTarget.indeterminate = false
    }
    
    this.updateBulkActions()
  }

  // Utility function
  debounce(func, wait) {
    let timeout
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout)
        func(...args)
      }
      clearTimeout(timeout)
      timeout = setTimeout(later, wait)
    }
  }
}