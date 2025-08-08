// app/javascript/controllers/warehouse_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sectionTitle", "sectionDate", "locationsGrid"]
  static values = { warehouseId: String }

  connect() {
    // Inicialización si es necesaria
  }

  async loadZoneLocations(event) {
    const zoneId = event.currentTarget.dataset.zoneId
    const sectionName = event.currentTarget.dataset.sectionName
    const sectionDate = event.currentTarget.dataset.sectionDate
    const sectionUsage = event.currentTarget.dataset.sectionUsage
    const sectionType = event.currentTarget.dataset.sectionType

    // Actualizar información de la sección
    this.updateSectionInfo(sectionName, sectionDate, sectionUsage, sectionType)

    // Resaltar fila seleccionada
    this.highlightSelectedRow(event.currentTarget)

    // Mostrar loading state
    this.locationsGridTarget.innerHTML = `
      <div class="col-span-3 flex justify-center items-center py-8">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-amber-500"></div>
      </div>
    `

    try {
      // Obtener ubicaciones desde el servidor
      const response = await fetch(`/admin/warehouses/${this.warehouseIdValue}/zones/${zoneId}/locations.json`)
      
      if (response.ok) {
        const locations = await response.json()
        this.renderLocations(locations)
      } else {
        throw new Error('Failed to fetch locations')
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

  updateSectionInfo(name, date, usage, type) {
    this.sectionTitleTarget.textContent = name
    this.sectionDateTarget.textContent = date
    
    // Puedes usar type para personalizar más la UI si es necesario
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
        <div class="col-span-3 text-center py-8 text-gray-500">
          No hay ubicaciones en esta zona
        </div>
      `
      return
    }

    // Agrupar ubicaciones en 3 columnas
    const columnSize = Math.ceil(locations.length / 3)
    let html = ''

    for (let col = 0; col < 3; col++) {
      html += `<div class="bg-gray-50 p-2 rounded-lg">`
      html += `<div class="grid grid-cols-2 gap-2">`

      const startIdx = col * columnSize
      const endIdx = Math.min(startIdx + columnSize, locations.length)

      for (let i = startIdx; i < endIdx; i++) {
        const loc = locations[i]
        const occupied = loc.stocks_count > 0
        const bgColor = occupied ? 'bg-amber-500' : 'bg-amber-200'
        const textColor = occupied ? 'text-white' : 'text-gray-700'
        const productNames = loc.product_names || 'Ocupado'
        const lastUpdated = loc.last_updated_formatted || ''

        html += `
          <div class="${bgColor} p-2 rounded text-xs ${occupied ? 'cursor-pointer hover:bg-amber-600' : ''}"
               data-location-id="${loc.id}"
               data-action="${occupied ? 'click->warehouse#showLocationDetails' : ''}">
            <div class="flex items-start">
              <div class="mr-2">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
                </svg>
              </div>
              <div>
                <h4 class="font-bold ${textColor}">${loc.aisle}-${loc.bay}-${loc.level}-${loc.position}</h4>
                ${occupied ? `
                  <p class="${textColor}">${productNames}</p>
                  <p class="text-xs ${occupied ? 'opacity-75' : ''}">${lastUpdated}</p>
                ` : `
                  <p class="${textColor}">Vacío</p>
                `}
              </div>
            </div>
          </div>
        `
      }

      html += `</div></div>`
    }

    this.locationsGridTarget.innerHTML = html
  }

  showLocationDetails(event) {
    const locationId = event.currentTarget.dataset.locationId
    // Aquí puedes implementar la lógica para mostrar detalles de la ubicación
    // Por ejemplo, abrir un modal o redirigir a la página de la ubicación
    console.log('Mostrar detalles de ubicación:', locationId)
  }
}