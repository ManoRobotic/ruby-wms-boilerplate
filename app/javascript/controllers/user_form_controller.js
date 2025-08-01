import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["role", "warehouse", "warehouseError"]

  connect() {
    this.updateWarehouseRequirement()
  }

  roleChanged() {
    this.updateWarehouseRequirement()
  }

  updateWarehouseRequirement() {
    const role = this.roleTarget.value
    const warehouseSelect = this.warehouseTarget
    const errorDiv = this.hasWarehouseErrorTarget ? this.warehouseErrorTarget : null
    
    if (role === 'admin') {
      // Admins don't require warehouse
      warehouseSelect.required = false  
      warehouseSelect.style.borderColor = ''
      if (errorDiv) errorDiv.classList.add('hidden')
    } else {
      // Other roles require warehouse
      warehouseSelect.required = true
      if (!warehouseSelect.value) {
        warehouseSelect.style.borderColor = '#f87171' // red-400
        if (errorDiv) errorDiv.classList.remove('hidden')
      } else {
        warehouseSelect.style.borderColor = ''
        if (errorDiv) errorDiv.classList.add('hidden')
      }
    }
  }

  warehouseChanged() {
    const warehouseSelect = this.warehouseTarget
    const role = this.roleTarget.value
    const errorDiv = this.hasWarehouseErrorTarget ? this.warehouseErrorTarget : null
    
    if (role !== 'admin' && warehouseSelect.value) {
      warehouseSelect.style.borderColor = '#10b981' // green-500
      if (errorDiv) errorDiv.classList.add('hidden')
    } else if (role !== 'admin' && !warehouseSelect.value) {
      warehouseSelect.style.borderColor = '#f87171' // red-400
      if (errorDiv) errorDiv.classList.remove('hidden')
    }
  }
}