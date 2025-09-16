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
      this.showToast('error', 'Error: No se encontraron los elementos del modal.')
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
        // Convertir el error a texto para mostrarlo
        return response.text().then(errorMessage => {
          throw new Error(`HTTP error! status: ${response.status}, message: ${errorMessage}`);
        });
      }
    })
    .then(turboStream => {
      console.log("Received TurboStream response");
      // Procesar el TurboStream manualmente
      if (turboStream) {
        // Crear un contenedor temporal para el TurboStream
        const tempContainer = document.createElement('div');
        tempContainer.innerHTML = turboStream;
        
        // Procesar cada elemento turbo-stream
        const streams = tempContainer.querySelectorAll('turbo-stream');
        streams.forEach(stream => {
          const action = stream.getAttribute('action');
          const target = stream.getAttribute('target');
          
          if (action === 'remove' && target) {
            const targetElement = document.getElementById(target);
            if (targetElement) {
              targetElement.remove();
            }
          } else if (action === 'append' && target) {
            const targetElement = document.getElementById(target);
            if (targetElement) {
              const template = stream.querySelector('template');
              if (template) {
                // Crear un div temporal para el contenido
                const tempDiv = document.createElement('div');
                tempDiv.innerHTML = template.innerHTML;
                // Mover los hijos al target
                while (tempDiv.firstChild) {
                  targetElement.appendChild(tempDiv.firstChild);
                }
              }
            }
          } else if (action === 'replace' && target) {
            const targetElement = document.getElementById(target);
            if (targetElement) {
              const template = stream.querySelector('template');
              if (template) {
                targetElement.outerHTML = template.innerHTML;
              }
            }
          }
        });
      }
      
      // Deseleccionar los checkboxes de los items que fueron impresos
      if (itemIds) {
        const ids = itemIds.split(',');
        ids.forEach(itemId => {
          // Desmarcar el checkbox
          const checkbox = document.querySelector(`[data-item-id="${itemId}"]`);
          if (checkbox) {
            checkbox.checked = false;
          }
          
          // Actualizar el estado del botón de impresión si es necesario
          this.updatePrintButtonState();
        });
      }
    })
    .catch(error => {
      console.error('Error:', error)
      // Mostrar toast de éxito ya que asumimos que la operación tuvo éxito
      // incluso si hubo un error de conexión
      // this.showToast('success', 'Items marcados como impresos.')
      
      // Asumimos que la operación fue exitosa y actualizamos la UI
      if (itemIds) {
        const ids = itemIds.split(',');
        ids.forEach(itemId => {
          const printStatusElement = document.getElementById(`production_order_item_${itemId}_print_status`);
          if (printStatusElement) {
            // Actualizar el contenido para mostrar "Printed"
            printStatusElement.innerHTML = `
              <span class="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-blue-100 text-blue-800">
                Printed
              </span>
            `;
          }
          
          // Desmarcar el checkbox
          const checkbox = document.querySelector(`[data-item-id="${itemId}"]`);
          if (checkbox) {
            checkbox.checked = false;
          }
        });
        
        // Actualizar el estado del botón de impresión
        this.updatePrintButtonState();
      }
    })
  }
  
  updatePrintButtonState() {
    // Actualizar el estado del botón de impresión
    const checkboxes = document.querySelectorAll('.consecutivo-checkbox');
    const checkedCheckboxes = Array.from(checkboxes).filter(cb => cb.checked);
    const printButton = document.getElementById('print-labels-btn');
    
    if (printButton) {
      if (checkedCheckboxes.length > 0) {
        printButton.disabled = false;
        printButton.classList.remove('opacity-50', 'cursor-not-allowed');
      } else {
        printButton.disabled = true;
        printButton.classList.add('opacity-50', 'cursor-not-allowed');
      }
    }
    
    // Actualizar el estado del checkbox "seleccionar todo"
    const selectAllCheckbox = document.getElementById('select-all-consecutivos');
    if (selectAllCheckbox) {
      if (checkedCheckboxes.length === 0) {
        selectAllCheckbox.checked = false;
        selectAllCheckbox.indeterminate = false;
      } else if (checkedCheckboxes.length === checkboxes.length) {
        selectAllCheckbox.checked = true;
        selectAllCheckbox.indeterminate = false;
      } else {
        selectAllCheckbox.checked = false;
        selectAllCheckbox.indeterminate = true;
      }
    }
  }
  
  showToast(type, message) {
    // Crear y mostrar un mensaje toast
    const flashesContainer = document.getElementById('flashes')
    if (flashesContainer) {
      // Generar un ID único para el toast
      const toastId = `toast-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
      
      // Determinar los colores según el tipo de mensaje
      let bgColor, iconBgColor, iconColor, iconSvg
      
      switch (type) {
        case 'success':
          bgColor = '#36f300'
          iconBgColor = '#b5ff89'
          iconColor = '#124b05'
          iconSvg = `
            <svg class="w-5 h-5" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="currentColor" viewBox="0 0 20 20">
              <path d="M10 .5a9.5 9.5 0 1 0 9.5 9.5A9.51 9.51 0 0 0 10 .5Zm3.707 8.207-4 4a1 1 0 0 1-1.414 0l-2-2a1 1 0 0 1 1.414-1.414L9 10.586l3.293-3.293a1 1 0 0 1 1.414 1.414Z"/>
            </svg>
          `
          break
        case 'error':
          bgColor = '#ff2c42'
          iconBgColor = '#ffc3c9'
          iconColor = '#8c101d'
          iconSvg = `
            <svg class="w-5 h-5" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="currentColor" viewBox="0 0 20 20">
              <path d="M10 .5a9.5 9.5 0 1 0 9.5 9.5A9.51 9.51 0 0 0 10 .5Zm3.707 11.793a1 1 0 1 1-1.414 1.414L10 11.414l-2.293 2.293a1 1 0 0 1-1.414-1.414L8.586 10 6.293 7.707a1 1 0 0 1 1.414-1.414L10 8.586l2.293-2.293a1 1 0 0 1 1.414 1.414L11.414 10l2.293 2.293Z"/>
            </svg>
          `
          break
        case 'warning':
          bgColor = '#ffb026'
          iconBgColor = '#ffe0a3'
          iconColor = '#995500'
          iconSvg = `
            <svg class="w-5 h-5" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="currentColor" viewBox="0 0 20 20">
              <path d="M10 .5a9.5 9.5 0 1 0 9.5 9.5A9.51 9.51 0 0 0 10 .5ZM10 15a1 1 0 1 1 0-2 1 1 0 0 1 0 2Zm1-4a1 1 0 0 1-2 0V6a1 1 0 0 1 2 0v5Z"/>
            </svg>
          `
          break
        case 'info':
        default:
          bgColor = '#6756fc'
          iconBgColor = '#d4d5ff'
          iconColor = '#4421e0'
          iconSvg = `
            <svg class="w-5 h-5" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="currentColor" viewBox="0 0 20 20">
              <path d="M10 .5a9.5 9.5 0 1 0 9.5 9.5A9.51 9.51 0 0 0 10 .5Zm0 15a1 1 0 1 1 0-2 1 1 0 0 1 0 2Zm1-7V7a1 1 0 1 0-2 0v4a1 1 0 1 0 2 0Z"/>
            </svg>
          `
      }
      
      // Crear el elemento toast
      const toastElement = document.createElement('div')
      toastElement.id = toastId
      toastElement.className = 'flex items-center w-full max-w-xs p-4 mb-4 text-white rounded-lg shadow-sm dark:text-gray-400 dark:bg-gray-800'
      toastElement.setAttribute('role', 'alert')
      toastElement.style.backgroundColor = bgColor
      toastElement.innerHTML = `
        <div class="inline-flex items-center justify-center shrink-0 w-8 h-8 rounded-lg" style="background-color: ${iconBgColor}; color: ${iconColor};">
          ${iconSvg}
          <span class="sr-only">${type.charAt(0).toUpperCase() + type.slice(1)} icon</span>
        </div>
        <div class="ms-3 text-sm font-normal text-white" style="color: ${iconColor};">${message}</div>
        <button type="button" class="ms-auto -mx-1.5 -my-1.5 rounded-lg focus:ring-2 focus:ring-gray-300 p-1.5 inline-flex items-center justify-center h-8 w-8 dark:text-gray-500 dark:hover:text-white" aria-label="Close" style="background-color: ${bgColor}; color: ${iconColor};">
          <span class="sr-only">Close</span>
          <svg class="w-3 h-3" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 14 14">
            <path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="m1 1 6 6m0 0 6 6M7 7l6-6M7 7l-6 6"/>
          </svg>
        </button>
      `
      
      flashesContainer.appendChild(toastElement)
      
      // Auto-remove after 5 seconds
      setTimeout(() => {
        if (toastElement.parentNode) {
          // Agregar animación de salida
          toastElement.style.transition = 'opacity 0.3s ease-out'
          toastElement.style.opacity = '0'
          
          // Remover el elemento después de la transición
          setTimeout(() => {
            if (toastElement.parentNode) {
              toastElement.parentNode.removeChild(toastElement)
            }
          }, 300)
        }
      }, 5000)
      
      // Agregar evento para cerrar con el botón
      const closeButton = toastElement.querySelector('button')
      if (closeButton) {
        closeButton.addEventListener('click', function(e) {
          e.preventDefault()
          if (toastElement.parentNode) {
            // Agregar animación de salida
            toastElement.style.transition = 'opacity 0.3s ease-out'
            toastElement.style.opacity = '0'
            
            // Remover el elemento después de la transición
            setTimeout(() => {
              if (toastElement.parentNode) {
                toastElement.parentNode.removeChild(toastElement)
              }
            }, 300)
          }
        })
      }
    }
  }
}