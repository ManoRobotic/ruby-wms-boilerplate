import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="print-form"
export default class extends Controller {
  static targets = ["weightField", "weightDisplay", "submitButton"]

  connect() {
    console.log("Print form controller connected")
    
    // Agregar event listeners para los radio buttons
    this.addFormatListeners()
    
    // Agregar event listener para el submit del formulario
    this.element.addEventListener('submit', this.submitForm.bind(this))
    
    // Validación inicial
    this.validatePrintButton()
    
    // Inicializar la visualización de campos según el formato seleccionado por defecto
    this.initializeFormatFields()
  }

  // Método para inicializar la visualización de campos según el formato seleccionado
  initializeFormatFields() {
    const selectedFormat = this.element.querySelector('input[name="format_type"]:checked')?.value || 'bag'
    // Create a mock event object to pass to toggleFormat
    const mockEvent = {
      target: {
        value: selectedFormat
      }
    }
    this.toggleFormat(mockEvent)
  }

  // Método actualizado para manejar eventos del controlador serial
  updateWeight(event) {
    const weight = event.detail.weight || "0.0"
    const numericWeight = parseFloat(weight.toString().replace(/[^\d.-]/g, '')) || 0.0
    
    console.log(`Received weight from serial: ${weight}, parsed: ${numericWeight}`)
    
    // Actualizar campo oculto del formulario
    this.weightFieldTarget.value = numericWeight.toFixed(1)
    
    // Actualizar display visual
    this.weightDisplayTargets.forEach(display => {
      display.textContent = `${numericWeight.toFixed(1)} kg`
    })
    
    // Validar si se puede imprimir
    this.validatePrintButton()
    
    // Ocultar warning de peso si hay peso válido y el elemento existe
    const warningDiv = document.getElementById('weight-warning')
    if (numericWeight > 0 && warningDiv) {
      warningDiv.classList.add('hidden')
    }
  }

  // Método para manejar cuando se imprime una etiqueta
  onLabelPrinted(event) {
    const content = event.detail.content
    console.log(`Label printed: ${content}`)
    
    // Mostrar mensaje de éxito
    this.showMessage(`Etiqueta impresa: ${content}`, 'success')
    
    // Opcionalmente resetear el formulario
    // this.resetForm()
  }

  // Método auxiliar para mostrar mensajes
  showMessage(message, type = 'info') {
    // Crear elemento de mensaje temporal
    const messageDiv = document.createElement('div')
    messageDiv.className = `fixed top-4 right-4 p-4 rounded-md shadow-lg z-50 ${
      type === 'success' ? 'bg-green-500 text-white' : 
      type === 'error' ? 'bg-red-500 text-white' : 
      'bg-blue-500 text-white'
    }`
    messageDiv.textContent = message
    
    document.body.appendChild(messageDiv)
    
    // Remover después de 3 segundos
    setTimeout(() => {
      if (document.body.contains(messageDiv)) {
        document.body.removeChild(messageDiv)
      }
    }, 3000)
  }

  addFormatListeners() {
    const radioButtons = this.element.querySelectorAll('input[name="format_type"]')
    radioButtons.forEach(radio => {
      radio.addEventListener('change', this.toggleFormat.bind(this))
    })
  }

  toggleFormat(event) {
    // Get the selected format value from the event
    const selectedFormat = event.target.value || event.target.querySelector('input[name="format_type"]:checked')?.value || 'bag'
    
    // Mostrar/ocultar campos según el formato seleccionado
    const bagFields = document.getElementById('bag-format-fields')
    const boxFields = document.getElementById('box-format-fields')
    
    if (selectedFormat === 'bag') {
      bagFields.classList.remove('hidden')
      boxFields.classList.add('hidden')
    } else {
      bagFields.classList.add('hidden')
      boxFields.classList.remove('hidden')
    }
    
    console.log(`Print format changed to: ${selectedFormat}`)
  }

  validatePrintButton() {
    const currentWeight = parseFloat(this.weightFieldTarget.value)
    const warningDiv = document.getElementById('weight-warning')
    
    if (currentWeight > 0) {
      // Habilitar el botón si hay peso
      if (this.hasSubmitButtonTarget) {
        this.submitButtonTarget.disabled = false
      }
      // Ocultar warning si existe
      if (warningDiv) {
        warningDiv.classList.add('hidden')
      }
    } else {
      // Deshabilitar el botón si no hay peso
      if (this.hasSubmitButtonTarget) {
        this.submitButtonTarget.disabled = true
      }
      // Mostrar warning si existe
      if (warningDiv) {
        warningDiv.classList.remove('hidden')
      }
    }
  }

  // Interceptar el submit del formulario para enviar a través del servicio serial
  async submitForm(event) {
    event.preventDefault()
    
    const currentWeight = parseFloat(this.weightFieldTarget.value)
    
    if (currentWeight <= 0) {
      this.showMessage('Debe capturar el peso antes de imprimir', 'error')
      this.validatePrintButton()
      return false
    }
    
    // Obtener datos del formulario
    const formData = new FormData(event.target)
    const printData = {
      product_name: formData.get('product_name') || 'Producto',
      barcode_data: formData.get('barcode_data') || '',
      current_weight: currentWeight.toFixed(1),
      format_type: formData.get('format_type') || 'bag',
      ancho_mm: formData.get('ancho_mm') || '80',
      alto_mm: formData.get('alto_mm') || '50',
      gap_mm: formData.get('gap_mm') || '2',
      // Campos específicos para formato bolsa
      bag_type: formData.get('bag_type') || '',
      bag_measurement: formData.get('bag_measurement') || '',
      pieces_count: formData.get('pieces_count') || '1',
      // Campos específicos para formato caja
      bag_type_box: formData.get('bag_type_box') || '',
      bag_measurement_box: formData.get('bag_measurement_box') || '',
      pieces_count_box: formData.get('pieces_count_box') || '1',
      package_count: formData.get('package_count') || '1',
      package_measurement: formData.get('package_measurement') || ''
    }
    
    // Generar contenido de etiqueta
    const labelContent = this.generateLabelContent(printData)
    
    try {
      // Obtener referencia al controlador serial
      const serialController = this.getSerialController()
      
      if (!serialController) {
        throw new Error('Controlador serial no disponible')
      }
      
      // Imprimir usando el servicio Flask
      this.showMessage('Imprimiendo etiqueta...', 'info')
      const success = await serialController.printCustomLabel(
        labelContent, 
        parseInt(printData.ancho_mm), 
        parseInt(printData.alto_mm)
      )
      
      if (success) {
        this.showMessage('Etiqueta impresa correctamente', 'success')
        console.log('Label printed successfully:', labelContent)
      } else {
        throw new Error('Error en impresión')
      }
      
    } catch (error) {
      console.error('Print error:', error)
      this.showMessage(`Error al imprimir: ${error.message}`, 'error')
    }
    
    return false
  }

  // Generar contenido de etiqueta basado en el formato
  generateLabelContent(data) {
    const timestamp = new Date().toLocaleString()
    
    switch (data.format_type) {
      case 'bag':
        return `${data.product_name}
Peso: ${data.current_weight}kg
Código: ${data.barcode_data}
Bolsa: ${data.bag_type || 'No especificada'}
Medida: ${data.bag_measurement || 'No especificada'}
Piezas: ${data.pieces_count || '1'}
${timestamp}`
      
      case 'box':
        return `CAJA: ${data.product_name}
Peso Total: ${data.current_weight}kg
Barcode: ${data.barcode_data}
Bolsa: ${data.bag_type_box || 'No especificada'}
Medida: ${data.bag_measurement_box || 'No especificada'}
Piezas: ${data.pieces_count_box || '1'}
Paquetes: ${data.package_count || '1'} de ${data.package_measurement || 'No especificadas'}
Fecha: ${timestamp}`
      
      default:
        return `${data.product_name} - ${data.current_weight}kg - ${data.barcode_data}`
    }
  }

  // Obtener referencia al controlador serial
  getSerialController() {
    const serialElement = document.querySelector('[data-controller*="serial"]')
    if (!serialElement) return null
    
    return this.application.getControllerForElementAndIdentifier(serialElement, 'serial')
  }

  disconnect() {
    // Cleanup si es necesario
  }
}