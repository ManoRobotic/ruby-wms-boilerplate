import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "itemIds" ]

  connect() {
    console.log("Production order item controller connected")
  }

  confirmPrint(event) {
    console.log("confirmPrint called");
    event.preventDefault()
    event.stopPropagation()
    
    // Obtener los IDs de los items desde el modal
    const itemIdsInput = document.getElementById('confirm-print-item-ids')
    const productionOrderIdInput = document.getElementById('confirm-print-production-order-id')
    
    if (!itemIdsInput || !productionOrderIdInput) {
      console.error("No se encontraron los elementos del modal")
      return
    }
    
    const itemIds = itemIdsInput.value
    const productionOrderId = productionOrderIdInput.value
    
    console.log("Item IDs to print:", itemIds);
    console.log("Production Order ID:", productionOrderId);
    
    // Cerrar el modal
    const modal = document.getElementById('confirm-print-modal')
    if (modal) {
      // Agregar una transición suave para ocultar el modal
      modal.classList.remove('opacity-100');
      modal.classList.add('opacity-0');
      
      // Esperar a que termine la transición antes de eliminar el elemento
      setTimeout(() => {
        if (modal && modal.parentNode) {
          modal.parentNode.removeChild(modal);
        }
      }, 300);
    }
    
    // Hacer la solicitud para obtener los datos de las etiquetas antes de marcar como impresos
    fetch(`/admin/production_orders/${productionOrderId}/items/confirm_print`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        'Accept': 'text/vnd.turbo-stream.html'
      },
      body: JSON.stringify({
        item_ids: itemIds
      })
    })
    .then(response => {
      console.log("Confirm print response status:", response.status);
      if (response.ok) {
        return response.text();
      } else {
        throw new Error('Network response was not ok.');
      }
    })
    .then(turboStream => {
      console.log("Received TurboStream response");
      // Procesar el TurboStream manualmente
      if (turboStream) {
        const template = document.createElement('template');
        template.innerHTML = turboStream;
        document.body.appendChild(template.content);
      }
    })
    .catch(error => {
      console.error('Error:', error)
      this.showFlashMessage('error', 'Error de conexión.')
    })
  }

  showFlashMessage(type, message) {
    // Crear y mostrar un mensaje flash
    const flashesContainer = document.getElementById('flashes')
    if (flashesContainer) {
      const alertClass = type === 'success' ? 'bg-green-100 border-green-400 text-green-700' : 'bg-red-100 border-red-400 text-red-700'
      const alertDiv = document.createElement('div')
      alertDiv.className = `border px-4 py-3 rounded relative ${alertClass} shadow-lg`
      alertDiv.innerHTML = `
        <span class="block sm:inline">${message}</span>
        <button onclick="this.parentElement.remove()" class="absolute top-0 bottom-0 right-0 px-4 py-3">
          <svg class="fill-current h-6 w-6" role="button" viewBox="0 0 20 20"><path d="M14.348 14.849a1.2 1.2 0 0 1-1.697 0L10 11.819l-2.651 3.029a1.2 1.2 0 1 1-1.697-1.697l2.758-3.15-2.759-3.152a1.2 1.2 0 1 1 1.697-1.697L10 8.183l2.651-3.031a1.2 1.2 0 1 1 1.697 1.697l-2.758 3.152 2.758 3.15a1.2 1.2 0 0 1 0 1.698z"/></svg>
        </button>
      `
      flashesContainer.appendChild(alertDiv)
      
      // Auto-remove after 5 seconds
      setTimeout(() => {
        if (alertDiv.parentNode) {
          alertDiv.remove()
        }
      }, 5000)
    }
  }
}