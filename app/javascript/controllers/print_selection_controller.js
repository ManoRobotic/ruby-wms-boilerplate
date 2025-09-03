import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  printSelected(event) {
    event.preventDefault()
    
    // Fetch the selected orders data from the server
    fetch('/admin/inventory_codes/selected_data', {
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
        console.log('DATOS DE CÓDIGOS DE INVENTARIO SELECCIONADOS:')
        console.log(JSON.stringify(data, null, 2))
        
        // Show a summary in console
        console.log('RESUMEN DE CÓDIGOS:')
        data.data.forEach((code, index) => {
          console.log(`${index + 1}. ${code.no_ordp} - ${code.cve_prod} (${code.status_display})`)
        })
        
        // Show success message to user
        alert(`✅ IMPRESIÓN COMPLETADA

Datos de ${data.count} códigos procesados exitosamente.

📄 Los documentos han sido enviados a imprimir
📋 Revisa la consola del navegador (F12) para ver los datos JSON completos`)
      } else {
        console.error('Error al obtener datos:', data.message)
        alert(`❌ ERROR EN LA IMPRESIÓN

No se pudieron obtener los datos de los códigos seleccionados.

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