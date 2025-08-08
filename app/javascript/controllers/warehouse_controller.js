// app/javascript/controllers/warehouse_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sectionTitle", "sectionDate", "locationsGrid", "actionButtons"]
  static values = { warehouseId: String, currentZoneId: String }

  connect() {
    // Inicialización si es necesaria
    this.deleteMode = false
  }

  async loadZoneLocations(event) {
    const zoneId = event.currentTarget.dataset.zoneId
    const sectionName = event.currentTarget.dataset.sectionName
    const sectionDate = event.currentTarget.dataset.sectionDate

    // Guardar el ID de la zona actual
    this.currentZoneIdValue = zoneId

    // Actualizar información de la sección
    this.updateSectionInfo(sectionName, sectionDate)

    // Mostrar botones de acción
    this.showActionButtons()

    // Resaltar fila seleccionada
    this.highlightSelectedRow(event.currentTarget)

    // Mostrar loading state
    this.locationsGridTarget.innerHTML = `
      <div class="col-span-3 flex justify-center items-center py-8">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-amber-500"></div>
      </div>
    `

    try {
      // Obtener token CSRF
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
      
      // Obtener ubicaciones desde el servidor
      const response = await fetch(`/admin/warehouses/${this.warehouseIdValue}/zones/${zoneId}/locations.json`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': csrfToken
        },
        credentials: 'same-origin'
      })
      
      if (response.ok) {
        const locations = await response.json()
        this.renderLocations(locations)
      } else {
        throw new Error(`Failed to fetch locations: ${response.status}`)
      }
    } catch (error) {
      console.error('Error loading locations:', error)
      this.locationsGridTarget.innerHTML = `
        <div class="col-span-3 text-center py-8 text-red-500">
          Error al cargar las ubicaciones. Intente nuevamente.
        </div>
      `
    }
  }

  updateSectionInfo(name, date) {
    this.sectionTitleTarget.textContent = name
    this.sectionDateTarget.textContent = date
  }

  showActionButtons() {
    if (this.hasActionButtonsTarget) {
      this.actionButtonsTarget.style.display = 'flex'
    }
  }

  hideActionButtons() {
    if (this.hasActionButtonsTarget) {
      this.actionButtonsTarget.style.display = 'none'
    }
  }

  highlightSelectedRow(selectedRow) {
    // Remover highlight de todas las filas
    document.querySelectorAll('[data-action="click->warehouse#loadZoneLocations"]').forEach(row => {
      row.classList.remove('bg-blue-50')
    })
    
    // Añadir highlight a la fila seleccionada
    selectedRow.classList.add('bg-blue-50')
  }

  renderLocations(locations) {
    if (locations.length === 0) {
      this.locationsGridTarget.innerHTML = `
        <div class="text-center py-8 text-gray-500">
          No hay ubicaciones en esta zona
        </div>
      `
      return
    }

    // Agrupar ubicaciones por zonas/secciones para crear el layout
    const sectionsHtml = this.createWarehouseSections(locations)
    this.locationsGridTarget.innerHTML = sectionsHtml
  }

  createWarehouseSections(locations) {
    // Crear una cuadrícula simple y limpia similar a la imagen de referencia
    let html = '<div class="bg-white rounded-lg p-6">'
    
    // Si no hay ubicaciones, mostrar mensaje
    if (locations.length === 0) {
      html += '<div class="text-center py-8 text-gray-500">No hay ubicaciones en esta zona</div>'
      html += '</div>'
      return html
    }
    
    // Agrupar ubicaciones por pasillo para mejor organización
    const locationsByAisle = this.groupLocationsByAisle(locations)
    
    // Crear una cuadrícula responsiva para cada pasillo
    Object.keys(locationsByAisle).sort().forEach(aisle => {
      const aisleLocations = locationsByAisle[aisle]
      
      html += `<div class="mb-6">`
      html += `<h4 class="text-sm font-medium text-gray-600 mb-3">Pasillo ${aisle}</h4>`
      html += `<div class="grid grid-cols-6 sm:grid-cols-8 md:grid-cols-10 lg:grid-cols-12 gap-2">`
      
      aisleLocations.forEach(location => {
        html += this.generateLocationBox(location)
      })
      
      html += '</div></div>'
    })
    
    html += '</div>'
    return html
  }

  groupLocationsByAisle(locations) {
    return locations.reduce((groups, location) => {
      const aisle = location.aisle || 'A'
      if (!groups[aisle]) {
        groups[aisle] = []
      }
      groups[aisle].push(location)
      return groups
    }, {})
  }

  generateLocationBox(loc) {
    const occupied = loc.stocks_count > 0
    const bgColor = occupied ? 'bg-yellow-400 border-yellow-500' : 'bg-yellow-100 border-yellow-200'
    const textColor = occupied ? 'text-gray-800' : 'text-gray-600'
    const hoverColor = occupied ? 'hover:bg-yellow-500' : 'hover:bg-yellow-200'
    
    // Agregar funcionalidad de eliminación en modo delete
    const deleteAction = this.deleteMode ? `data-action="click->warehouse#deleteLocation" data-location-id="${loc.id}"` : ''
    const deleteClass = this.deleteMode ? 'cursor-pointer border-red-300 hover:bg-red-100' : ''
    const normalAction = occupied && !this.deleteMode ? `data-location-id="${loc.id}" data-action="click->warehouse#showLocationDetails"` : ''
    
    return `
      <div class="relative group ${occupied && !this.deleteMode ? 'cursor-pointer' : ''} ${deleteClass}" 
           ${this.deleteMode ? deleteAction : normalAction}>
        <div class="w-16 h-16 ${this.deleteMode ? 'bg-red-50 border-red-300' : bgColor} border-2 rounded-lg ${this.deleteMode ? 'hover:bg-red-100' : hoverColor} transition-colors duration-200 flex items-center justify-center">
          ${this.deleteMode ? `
            <div class="text-red-600 text-lg">❌</div>
          ` : `
            <div class="text-center">
              <div class="${textColor} text-xs font-bold">
                ${loc.bay || '?'}${loc.position || ''}
              </div>
              ${occupied ? `
                <div class="w-2 h-2 bg-gray-700 rounded-full mx-auto mt-1"></div>
              ` : ''}
            </div>
          `}
        </div>
        
        ${occupied && !this.deleteMode ? `
          <div class="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-2 py-1 bg-gray-800 text-white text-xs rounded whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity duration-200 pointer-events-none z-10">
            ${loc.product_names ? loc.product_names.substring(0, 30) + (loc.product_names.length > 30 ? '...' : '') : 'Ubicación ocupada'}
          </div>
        ` : ''}
        
        ${this.deleteMode ? `
          <div class="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-2 py-1 bg-red-600 text-white text-xs rounded whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity duration-200 pointer-events-none z-10">
            Hacer clic para eliminar
          </div>
        ` : ''}
      </div>
    `
  }


  showLocationDetails(event) {
    event.preventDefault()
    const locationId = event.currentTarget.dataset.locationId
    
    // Crear modal simple para mostrar detalles
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50'
    modal.innerHTML = `
      <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4">
        <div class="flex justify-between items-center mb-4">
          <h3 class="text-lg font-semibold">Detalles de Ubicación</h3>
          <button class="text-gray-500 hover:text-gray-700" onclick="this.closest('.fixed').remove()">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>
        <div id="location-details-content">
          <div class="text-center py-4">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto"></div>
            <p class="mt-2 text-gray-600">Cargando detalles...</p>
          </div>
        </div>
        <div class="flex justify-end mt-6">
          <button class="px-4 py-2 bg-gray-300 text-gray-700 rounded hover:bg-gray-400" onclick="this.closest('.fixed').remove()">
            Cerrar
          </button>
        </div>
      </div>
    `
    
    document.body.appendChild(modal)
    
    // Cargar detalles de la ubicación
    this.loadLocationDetails(locationId)
  }
  
  async loadLocationDetails(locationId) {
    try {
      // Obtener token CSRF
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
      
      const response = await fetch(`/admin/warehouses/${this.warehouseIdValue}/zones/1/locations/${locationId}.json`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': csrfToken
        },
        credentials: 'same-origin'
      })
      
      if (response.ok) {
        const location = await response.json()
        this.displayLocationDetails(location)
      } else {
        this.showLocationError('Error al cargar los detalles')
      }
    } catch (error) {
      this.showLocationError('Error de conexión')
    }
  }
  
  displayLocationDetails(location) {
    const content = document.getElementById('location-details-content')
    if (!content) return
    
    content.innerHTML = `
      <div class="space-y-4">
        <div>
          <h4 class="font-semibold text-gray-900">Ubicación: ${location.full_code || location.aisle + '-' + location.bay + '-' + location.level}</h4>
          <p class="text-sm text-gray-600">Tipo: ${location.location_type || 'Standard'}</p>
        </div>
        
        ${location.stocks && location.stocks.length > 0 ? `
          <div>
            <h5 class="font-medium text-gray-900 mb-2">Productos almacenados:</h5>
            <div class="space-y-2">
              ${location.stocks.map(stock => `
                <div class="bg-gray-50 p-2 rounded">
                  <p class="font-medium text-sm">${stock.product?.name || 'Producto'}</p>
                  <p class="text-xs text-gray-600">SKU: ${stock.product?.sku || 'N/A'}</p>
                  <p class="text-xs text-gray-600">Cantidad: ${stock.quantity}</p>
                </div>
              `).join('')}
            </div>
          </div>
        ` : `
          <div class="text-center py-4">
            <p class="text-gray-500">Esta ubicación está vacía</p>
          </div>
        `}
        
        ${location.last_updated_formatted ? `
          <div>
            <p class="text-xs text-gray-500">Última actualización: ${location.last_updated_formatted}</p>
          </div>
        ` : ''}
      </div>
    `
  }
  
  showLocationError(message) {
    const content = document.getElementById('location-details-content')
    if (!content) return
    
    content.innerHTML = `
      <div class="text-center py-4">
        <div class="text-red-600 mb-2">
          <svg class="w-8 h-8 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
          </svg>
        </div>
        <p class="text-red-600">${message}</p>
      </div>
    `
  }

  // Nuevos métodos para gestionar ubicaciones
  showAddLocationModal(event) {
    event.preventDefault()
    
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50'
    modal.innerHTML = `
      <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4">
        <div class="flex justify-between items-center mb-4">
          <h3 class="text-lg font-semibold">Agregar Nueva Ubicación</h3>
          <button class="text-gray-500 hover:text-gray-700" onclick="this.closest('.fixed').remove()">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>
        <form id="add-location-form">
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700">Pasillo</label>
              <input type="text" id="aisle" name="aisle" required class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:border-blue-500 focus:ring-blue-500" placeholder="01">
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Bahía</label>
              <input type="text" id="bay" name="bay" required class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:border-blue-500 focus:ring-blue-500" placeholder="01">
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Nivel</label>
              <input type="text" id="level" name="level" required class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:border-blue-500 focus:ring-blue-500" placeholder="1">
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Posición</label>
              <input type="text" id="position" name="position" required class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:border-blue-500 focus:ring-blue-500" placeholder="01">
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700">Tipo</label>
              <select id="location_type" name="location_type" class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:border-blue-500 focus:ring-blue-500">
                <option value="bin">Bin</option>
                <option value="shelf">Shelf</option>
                <option value="floor">Floor</option>
              </select>
            </div>
          </div>
          <div class="flex justify-end mt-6 space-x-2">
            <button type="button" class="px-4 py-2 bg-gray-300 text-gray-700 rounded hover:bg-gray-400" onclick="this.closest('.fixed').remove()">
              Cancelar
            </button>
            <button type="submit" class="px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600">
              Crear Ubicación
            </button>
          </div>
        </form>
      </div>
    `
    
    document.body.appendChild(modal)
    
    // Manejar el formulario
    const form = document.getElementById('add-location-form')
    form.addEventListener('submit', (e) => this.handleAddLocation(e, modal))
  }

  async handleAddLocation(event, modal) {
    event.preventDefault()
    
    const formData = new FormData(event.target)
    const locationData = Object.fromEntries(formData.entries())
    
    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
      
      const response = await fetch(`/admin/warehouses/${this.warehouseIdValue}/zones/${this.currentZoneIdValue}/locations`, {
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        credentials: 'same-origin',
        body: JSON.stringify({ location: locationData })
      })
      
      if (response.ok) {
        modal.remove()
        // Recargar las ubicaciones
        this.refreshLocations()
        this.showSuccessMessage('Ubicación creada exitosamente')
      } else {
        const error = await response.text()
        this.showErrorMessage('Error al crear la ubicación: ' + error)
      }
    } catch (error) {
      console.error('Error creating location:', error)
      this.showErrorMessage('Error de conexión al crear la ubicación')
    }
  }

  toggleDeleteMode(event) {
    event.preventDefault()
    
    this.deleteMode = !this.deleteMode
    const button = event.currentTarget
    
    if (this.deleteMode) {
      button.textContent = '❌ Cancelar Eliminación'
      button.className = 'px-3 py-1 bg-red-500 text-white rounded hover:bg-red-600 text-sm'
    } else {
      button.textContent = '🗑️ Eliminar Ubicaciones'
      button.className = 'px-3 py-1 bg-blue-500 text-white rounded hover:bg-blue-600 text-sm'
    }
    
    // Recargar vista con el modo actualizado
    this.refreshLocations()
  }

  async deleteLocation(event) {
    event.preventDefault()
    
    if (!confirm('¿Está seguro de que desea eliminar esta ubicación?')) {
      return
    }
    
    const locationId = event.currentTarget.dataset.locationId
    
    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
      
      const response = await fetch(`/admin/warehouses/${this.warehouseIdValue}/zones/${this.currentZoneIdValue}/locations/${locationId}`, {
        method: 'DELETE',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': csrfToken
        },
        credentials: 'same-origin'
      })
      
      if (response.ok) {
        this.refreshLocations()
        this.showSuccessMessage('Ubicación eliminada exitosamente')
      } else {
        const error = await response.text()
        this.showErrorMessage('Error al eliminar la ubicación: ' + error)
      }
    } catch (error) {
      console.error('Error deleting location:', error)
      this.showErrorMessage('Error de conexión al eliminar la ubicación')
    }
  }

  showLocationsList(event) {
    event.preventDefault()
    window.open(`/admin/warehouses/${this.warehouseIdValue}/zones/${this.currentZoneIdValue}/locations`, '_blank')
  }

  async refreshLocations() {
    if (!this.currentZoneIdValue) return
    
    // Simular el evento para recargar las ubicaciones
    const mockEvent = {
      currentTarget: {
        dataset: {
          zoneId: this.currentZoneIdValue,
          sectionName: this.sectionTitleTarget.textContent,
          sectionDate: this.sectionDateTarget.textContent
        }
      }
    }
    
    await this.loadZoneLocations(mockEvent)
  }

  showSuccessMessage(message) {
    const alert = document.createElement('div')
    alert.className = 'fixed top-4 right-4 bg-green-500 text-white px-4 py-2 rounded shadow-lg z-50'
    alert.textContent = message
    document.body.appendChild(alert)
    
    setTimeout(() => alert.remove(), 3000)
  }

  showErrorMessage(message) {
    const alert = document.createElement('div')
    alert.className = 'fixed top-4 right-4 bg-red-500 text-white px-4 py-2 rounded shadow-lg z-50'
    alert.textContent = message
    document.body.appendChild(alert)
    
    setTimeout(() => alert.remove(), 5000)
  }
}