import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["weightInput", "weightDisplay", "weightStatus", "modal", "modalTitle", "modalContent"]

  connect() {
    console.log("Production Order controller connected")
    // Si estamos en la vista show, obtener el ID desde el elemento
    if (this.element.dataset.orderId) {
      this.currentOrderId = this.element.dataset.orderId
    }
  }

  // Abrir modal de detalles
  async openModal(event) {
    event.preventDefault()
    event.stopPropagation()
    
    // Obtener el ID de la orden desde el elemento clickeado
    const orderId = event.target.closest('[data-order-id]')?.dataset.orderId ||
                   event.currentTarget.dataset.orderId
    
    if (!orderId) {
      console.error('No se encontró ID de orden')
      return
    }
    
    // Guardar el ID para otros métodos
    this.currentOrderId = orderId
    
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove('hidden')
      document.body.classList.add('overflow-hidden')
      
      // Fetch order details
      try {
        const response = await fetch(`/admin/production_orders/${orderId}/modal_details`)
        if (response.ok) {
          const data = await response.json()
          this.populateModal(data)
        } else {
          this.showError('Error al cargar los datos de la orden')
        }
      } catch (error) {
        this.showError('Error de conexión')
      }
    }
  }

  // Cerrar modal
  closeModal(event) {
    event.preventDefault()
    if (this.hasModalTarget) {
      this.modalTarget.classList.add('hidden')
      document.body.classList.remove('overflow-hidden')
    }
  }

  // Evitar propagación del evento
  stopPropagation(event) {
    event.stopPropagation()
  }

  // Conectar con la báscula
  async connectScale(event) {
    event.preventDefault()
    this.updateWeightStatus("Conectando con báscula...", "connecting")
    
    try {
      // Simular conexión - en producción aquí iría la lógica real de conexión con la báscula
      await this.simulateScaleConnection()
      this.updateWeightStatus("Báscula conectada", "connected")
    } catch (error) {
      this.updateWeightStatus("Error de conexión", "error")
    }
  }

  // Leer peso de la báscula
  async readWeight(event) {
    event.preventDefault()
    this.updateWeightStatus("Leyendo peso...", "reading")
    
    try {
      // Simular lectura de peso - en producción aquí iría la lógica real
      const weight = await this.simulateWeightReading()
      
      if (this.hasWeightInputTarget) {
        this.weightInputTarget.value = weight
      }
      
      if (this.hasWeightDisplayTarget) {
        this.weightDisplayTarget.textContent = `${weight} kg`
      }
      
      this.updateWeightStatus("Peso leído correctamente", "success")
    } catch (error) {
      this.updateWeightStatus("Error al leer peso", "error")
    }
  }

  // Guardar peso
  async saveWeight(event) {
    event.preventDefault()
    
    const weight = this.hasWeightInputTarget ? this.weightInputTarget.value : null
    
    if (!weight || weight <= 0) {
      this.updateWeightStatus("Por favor ingrese un peso válido", "error")
      return
    }

    this.updateWeightStatus("Guardando peso...", "saving")
    
    try {
      const response = await fetch(`/admin/production_orders/${this.currentOrderId}/update_weight`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        },
        body: JSON.stringify({ peso: weight })
      })

      const data = await response.json()
      
      if (data.success) {
        this.updateWeightStatus(data.message, "success")
        // Actualizar display de peso guardado
        if (this.hasWeightDisplayTarget) {
          this.weightDisplayTarget.textContent = `${data.peso} kg (Guardado)`
        }
      } else {
        this.updateWeightStatus(data.error, "error")
      }
    } catch (error) {
      this.updateWeightStatus("Error al guardar peso", "error")
    }
  }

  // Imprimir orden directamente
  async printOrder(event) {
    event.preventDefault()
    
    try {
      // Imprimir usando el formato bag por defecto (puedes cambiarlo según necesites)
      const printUrl = `/admin/production_orders/${this.currentOrderId}/print_bag_format`
      window.open(printUrl, '_blank')
    } catch (error) {
      console.error('Error al imprimir:', error)
    }
  }

  // Métodos auxiliares
  updateWeightStatus(message, type) {
    if (this.hasWeightStatusTarget) {
      this.weightStatusTarget.textContent = message
      
      // Remover clases de estado anteriores
      this.weightStatusTarget.classList.remove('text-green-600', 'text-blue-600', 'text-red-600', 'text-yellow-600')
      
      // Agregar clase según el tipo
      switch (type) {
        case 'success':
        case 'connected':
          this.weightStatusTarget.classList.add('text-green-600')
          break
        case 'connecting':
        case 'reading':
        case 'saving':
          this.weightStatusTarget.classList.add('text-blue-600')
          break
        case 'error':
          this.weightStatusTarget.classList.add('text-red-600')
          break
        default:
          this.weightStatusTarget.classList.add('text-gray-600')
      }
    }
  }

  async simulateScaleConnection() {
    // Simular tiempo de conexión
    return new Promise((resolve) => {
      setTimeout(resolve, 1500)
    })
  }

  async simulateWeightReading() {
    // Simular lectura de peso (devuelve peso aleatorio entre 10-500 kg)
    return new Promise((resolve) => {
      setTimeout(() => {
        const weight = (Math.random() * 490 + 10).toFixed(2)
        resolve(weight)
      }, 1000)
    })
  }

  // Poblar el modal con los datos de la orden
  populateModal(data) {
    if (this.hasModalTitleTarget) {
      this.modalTitleTarget.textContent = `Orden: ${data.no_opro || data.order_number}`
    }

    if (this.hasModalContentTarget) {
      const statusColor = this.getStatusColor(data.status)
      const priorityColor = this.getPriorityColor(data.priority)
      
      this.modalContentTarget.innerHTML = `
        <!-- Order Header -->
        <div class="bg-gray-50 rounded-lg p-4 mb-6">
          <div class="flex justify-between items-start">
            <div>
              <h4 class="text-lg font-semibold text-gray-900">${data.product_name}</h4>
              <p class="text-sm text-gray-600">No. OPRO: ${data.no_opro || data.order_number}</p>
            </div>
            <div class="flex space-x-2">
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${statusColor}">
                ${data.status.charAt(0).toUpperCase() + data.status.slice(1)}
              </span>
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${priorityColor}">
                ${data.priority.charAt(0).toUpperCase() + data.priority.slice(1)}
              </span>
            </div>
          </div>
        </div>

        <!-- Main Details -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
          <!-- Left Column -->
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700">Almacén</label>
              <p class="text-sm text-gray-900">${data.warehouse_name}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Lote de Referencia</label>
              <p class="text-sm text-gray-900">${data.lote_referencia || 'N/A'}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Cantidad Solicitada</label>
              <p class="text-sm text-gray-900 font-semibold">${data.quantity_requested}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Carga</label>
              <p class="text-sm text-gray-900">${data.carga_copr || 'N/A'}</p>
            </div>
          </div>

          <!-- Right Column -->
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700">Fecha</label>
              <p class="text-sm text-gray-900">${data.fecha_completa || data.created_at}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Año / Mes</label>
              <p class="text-sm text-gray-900">${data.ano || 'N/A'} / ${data.mes || 'N/A'}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Cantidad Producida</label>
              <p class="text-sm text-gray-900">${data.quantity_produced}</p>
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Progreso</label>
              <div class="flex items-center space-x-2">
                <div class="flex-1 bg-gray-200 rounded-full h-2">
                  <div class="bg-blue-600 h-2 rounded-full" style="width: ${data.progress_percentage}%"></div>
                </div>
                <span class="text-xs text-gray-600">${data.progress_percentage}%</span>
              </div>
            </div>
          </div>
        </div>

        <!-- Weight Section -->
        <div class="bg-blue-50 rounded-lg p-4 mb-6">
          <h5 class="text-md font-semibold text-gray-900 mb-3">Control de Peso</h5>
          <div class="flex items-center space-x-4">
            <div class="flex-1">
              <label class="block text-sm font-medium text-gray-700">Peso Actual</label>
              <div class="flex items-center space-x-2">
                <input type="number" 
                       data-production-order-target="weightInput"
                       class="mt-1 block w-32 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                       placeholder="0.00"
                       step="0.01"
                       value="${data.peso || ''}">
                <span class="text-sm text-gray-600">kg</span>
              </div>
            </div>
            <div class="flex flex-col space-y-2">
              <button class="px-3 py-1 bg-blue-600 text-white text-xs rounded hover:bg-blue-700"
                      data-action="click->production-order#connectScale">
                Conectar Báscula
              </button>
              <button class="px-3 py-1 bg-green-600 text-white text-xs rounded hover:bg-green-700"
                      data-action="click->production-order#readWeight">
                Leer Peso
              </button>
              <button class="px-3 py-1 bg-purple-600 text-white text-xs rounded hover:bg-purple-700"
                      data-action="click->production-order#saveWeight">
                Guardar Peso
              </button>
            </div>
          </div>
          <div class="mt-2">
            <p class="text-sm text-gray-600" data-production-order-target="weightStatus">
              ${data.peso ? `Peso guardado: ${data.peso} kg` : 'Sin peso registrado'}
            </p>
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="flex justify-end space-x-3 pt-4 border-t">
          <button class="px-4 py-2 bg-purple-600 text-white text-sm rounded hover:bg-purple-700"
                  data-action="click->production-order#printOrder">
            <i class="fas fa-print mr-1"></i>
            Imprimir Orden
          </button>
          <button class="px-4 py-2 bg-gray-300 text-gray-700 text-sm rounded hover:bg-gray-400"
                  data-action="click->production-order#closeModal">
            Cerrar
          </button>
        </div>
      `
    }
  }

  // Mostrar error en el modal
  showError(message) {
    if (this.hasModalContentTarget) {
      this.modalContentTarget.innerHTML = `
        <div class="text-center py-4">
          <div class="text-red-600 mb-2">
            <i class="fas fa-exclamation-triangle text-2xl"></i>
          </div>
          <p class="text-red-600">${message}</p>
          <button class="mt-4 px-4 py-2 bg-gray-300 text-gray-700 rounded hover:bg-gray-400"
                  data-action="click->production-order#closeModal">
            Cerrar
          </button>
        </div>
      `
    }
  }

  // Obtener color para el estado
  getStatusColor(status) {
    const colors = {
      'pending': 'bg-yellow-100 text-yellow-800',
      'scheduled': 'bg-blue-100 text-blue-800',
      'in_progress': 'bg-green-100 text-green-800',
      'paused': 'bg-orange-100 text-orange-800',
      'completed': 'bg-gray-100 text-gray-800',
      'cancelled': 'bg-red-100 text-red-800'
    }
    return colors[status] || 'bg-gray-100 text-gray-800'
  }

  // Obtener color para la prioridad
  getPriorityColor(priority) {
    const colors = {
      'low': 'bg-gray-100 text-gray-800',
      'medium': 'bg-blue-100 text-blue-800',
      'high': 'bg-orange-100 text-orange-800',
      'urgent': 'bg-red-100 text-red-800'
    }
    return colors[priority] || 'bg-gray-100 text-gray-800'
  }
}