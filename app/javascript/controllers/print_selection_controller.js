import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  printSelected(event) {
    event.preventDefault()
    
    const selectedCheckboxes = document.querySelectorAll('.order-checkbox:checked')
    
    if (selectedCheckboxes.length === 0) {
      alert('Por favor selecciona al menos una orden para imprimir.')
      return
    }

    // First get the count of selected orders from the counter
    const counterElement = document.getElementById('selected-count')
    const selectedCount = counterElement ? parseInt(counterElement.textContent) : selectedCheckboxes.length

    // Show confirmation dialog with warning about material waste
    const confirmMessage = `⚠️ CONFIRMACIÓN DE IMPRESIÓN ⚠️

¿Estás seguro de que quieres imprimir ${selectedCount} órdenes de producción?

⚠️ ADVERTENCIA: Esta operación consumirá material de impresión y no se puede deshacer.

• Se imprimirán ${selectedCount} documentos
• Se consumirá papel y tinta/tóner
• Revisa que las órdenes seleccionadas sean correctas

¿Proceder con la impresión?`

    if (!confirm(confirmMessage)) {
      return
    }
    
    // Fetch the selected orders data from the server
    fetch('/admin/production_orders/selected_orders_data', {
      method: "GET",
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content,
        "Accept": "application/json"
      }
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.json()
    })
    .then(data => {
      if (data.status === "success") {
        // Log data to console as requested
        console.log('DATOS DE ÓRDENES SELECCIONADAS:')
        console.log(JSON.stringify(data, null, 2))
        
        // Show a summary in console
        console.log('RESUMEN DE ÓRDENES:')
        data.data.forEach((order, index) => {
          console.log(`${index + 1}. ${order.no_opro || order.order_number} - ${order.product.name} (${order.status})`)
        })
        
        // Show success message to user
        alert(`✅ IMPRESIÓN COMPLETADA

Datos de ${data.count} órdenes procesados exitosamente.

📄 Los documentos han sido enviados a imprimir
📋 Revisa la consola del navegador (F12) para ver los datos JSON completos
⚠️ Recuerda verificar que la impresora tenga suficiente papel y tinta`)
      } else {
        console.error('Error al obtener datos:', data.message)
        alert(`❌ ERROR EN LA IMPRESIÓN

No se pudieron obtener los datos de las órdenes seleccionadas.

🔧 Detalles: ${data.message}
💡 Intenta recargar la página e intentar nuevamente`)
      }
    })
    .catch(error => {
      console.error('Error en la petición:', error)
      alert(`❌ ERROR DE COMUNICACIÓN

No se pudo conectar con el servidor para procesar la impresión.

🔧 Detalles: Error de red o servidor
💡 Verifica tu conexión e intenta nuevamente`)
    })
  }
}