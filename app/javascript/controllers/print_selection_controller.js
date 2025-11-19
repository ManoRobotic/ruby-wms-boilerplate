import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  printSelected(event) {
    event.preventDefault()

    // First, get the selected inventory codes from the session
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

        // Now send the selected IDs to the print endpoint to actually print the labels
        return this.sendPrintRequest(data.data.map(code => code.id))
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

  async sendPrintRequest(selectedIds) {
    try {
      const response = await fetch('/admin/inventory_codes/print_selected_labels', {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content,
          "Content-Type": "application/json",
          "Accept": "application/json"
        },
        body: JSON.stringify({ selected_ids: selectedIds })
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const result = await response.json()

      if (result.status === "success") {
        if (result.print_success) {
          // Show success message to user
          alert(`✅ IMPRESIÓN COMPLETADA

${result.count} etiquetas han sido enviadas a la impresora exitosamente.

📋 Revisa la consola del navegador (F12) para ver los datos JSON completos`)
        } else {
          // Show partial success message
          alert(`⚠️ IMPRESIÓN PARCIAL

${result.count} códigos procesados pero hubo un problema al enviar a la impresora.

🔧 Verifica que la impresora esté conectada y configurada correctamente
📋 Revisa la consola del navegador (F12) para ver los datos JSON completos`)
        }
      } else {
        console.error('Error al imprimir:', result.message)
        alert(`❌ ERROR EN LA IMPRESIÓN

No se pudieron imprimir las etiquetas.

🔧 Detalles: ${result.message}
💡 Intenta recargar la página e intentar nuevamente`)
      }
    } catch (error) {
      console.error('Error al intentar imprimir:', error)
      alert(`❌ ERROR DE COMUNICACIÓN

No se pudo conectar con el servidor para procesar la impresión.

🔧 Detalles: Error de red o servidor
💡 Verifica tu conexión e intenta nuevamente`)
    }
  }
}