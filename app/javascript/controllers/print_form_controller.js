import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="print-form"
export default class extends Controller {
  static targets = ["weightField", "weightDisplay", "submitButton", "bagFields", "rollFields", "boxFields"];

  connect() {
    console.log("Print form controller connected - VERSION DEBUG");
    // alert("DEBUG: Print Controller Updated!"); // Uncomment if needed, but console log is safer first
    
    // Agregar event listeners para los radio buttons
    this.addFormatListeners();

    // Agregar event listener para el submit del formulario
    this.element.addEventListener("submit", this.submitForm.bind(this));

    // Validación inicial
    this.validatePrintButton();

    // Inicializar la visualización de campos según el formato seleccionado por defecto
    this.initializeFormatFields();

    // Add event listeners to form fields to revalidate on change
    const formFields = this.element.querySelectorAll("input, select, textarea");
    formFields.forEach((field) => {
      field.addEventListener("input", this.validatePrintButton.bind(this));
      field.addEventListener("change", this.validatePrintButton.bind(this));
    });
  }

  // Método para inicializar la visualización de campos según el formato seleccionado
  initializeFormatFields() {
    const selectedFormat =
      this.element.querySelector('input[name="format_type"]:checked')?.value ||
      "bag";
    // Create a mock event object to pass to toggleFormat
    const mockEvent = {
      target: {
        value: selectedFormat,
      },
    };
    this.toggleFormat(mockEvent);
  }

  // Método actualizado para manejar eventos del controlador serial
  updateWeight(event) {
    const weight = event.detail.weight || "0.0";
    const numericWeight =
      parseFloat(weight.toString().replace(/[^\d.-]/g, "")) || 0.0;

    console.log(
      `Received weight from serial: ${weight}, parsed: ${numericWeight}`
    );

    // Actualizar campo oculto del formulario
    this.weightFieldTarget.value = numericWeight.toFixed(1);

    // Actualizar display visual
    this.weightDisplayTargets.forEach((display) => {
      display.textContent = `${numericWeight.toFixed(1)} kg`;
    });

    // Validar si se puede imprimir
    this.validatePrintButton();

    // Ocultar warning de peso si hay peso válido y el elemento existe
    const warningDiv = document.getElementById("weight-warning");
    if (numericWeight > 0 && warningDiv) {
      warningDiv.classList.add("hidden");
    }
  }

  // Método para manejar cuando se imprime una etiqueta
  onLabelPrinted(event) {
    const content = event.detail.content;
    console.log(`Label printed: ${content}`);

    // Mostrar mensaje de éxito
    this.showMessage(`Etiqueta impresa: ${content}`, "success");

    // Opcionalmente resetear el formulario
    // this.resetForm()
  }

  // Método auxiliar para mostrar mensajes
  showMessage(message, type = "info") {
    // Crear elemento de mensaje temporal
    const messageDiv = document.createElement("div");
    messageDiv.className = `fixed top-4 right-4 p-4 rounded-md shadow-lg z-50 ${
      type === "success"
        ? "bg-green-500 text-white"
        : type === "error"
        ? "bg-red-500 text-white"
        : "bg-blue-500 text-white"
    }`;
    messageDiv.textContent = message;

    document.body.appendChild(messageDiv);

    // Remover después de 3 segundos
    setTimeout(() => {
      if (document.body.contains(messageDiv)) {
        document.body.removeChild(messageDiv);
      }
    }, 3000);
  }

  addFormatListeners() {
    const radioButtons = this.element.querySelectorAll(
      'input[name="format_type"]'
    );
    radioButtons.forEach((radio) => {
      radio.addEventListener("change", this.toggleFormat.bind(this));
    });
  }

  toggleFormat(event) {
    // Get the selected format value from the event
    const selectedFormat =
      event.target.value ||
      event.target.querySelector('input[name="format_type"]:checked')?.value ||
      "bag";

    // Mostrar/ocultar campos según el formato seleccionado
    // Ocultar todos primero
    if (this.hasBagFieldsTarget) this.bagFieldsTarget.classList.add('hidden')
    if (this.hasRollFieldsTarget) this.rollFieldsTarget.classList.add('hidden')
    if (this.hasBoxFieldsTarget) this.boxFieldsTarget.classList.add('hidden')
    
    // Mostrar solo el seleccionado
    if (selectedFormat === 'bag' && this.hasBagFieldsTarget) {
      this.bagFieldsTarget.classList.remove('hidden')
    } else if (selectedFormat === 'roll' && this.hasRollFieldsTarget) {
      this.rollFieldsTarget.classList.remove('hidden')
    } else if (selectedFormat === 'box' && this.hasBoxFieldsTarget) {
      this.boxFieldsTarget.classList.remove('hidden')
    }

    console.log(`Print format changed to: ${selectedFormat}`);
  }

  validatePrintButton() {
    // Check if there's a weight field target
    let isValid = true;

    if (this.hasWeightFieldTarget) {
      const currentWeight = parseFloat(this.weightFieldTarget.value);

      // For manual printing, we set a default weight of 1.0, so we just need to check if it's valid
      if (currentWeight > 0) {
        // Valid weight
        isValid = true;
      } else {
        // Invalid weight
        isValid = false;
      }
    } else {
      // No weight field, check if form has required fields filled
      const productName = this.element.querySelector(
        'input[name="product_name"]'
      )?.value;
      const barcodeData = this.element.querySelector(
        'input[name="barcode_data"]'
      )?.value;

      // At minimum we need product name and barcode
      if (productName && barcodeData) {
        isValid = true;
      } else {
        isValid = false;
      }
    }

    // Enable or disable the submit button based on validation
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = !isValid;
    }
  }

  // Handle print button click - show confirmation modal
  handlePrintButtonClick() {
    console.log("Handle print button click - setting up listener");
    // Dispatch event to open confirm print modal
    const openEvent = new CustomEvent("open-confirm-print-modal", {
      detail: {
        selectedCount: 1,
        selectedIds: [],
      },
    });
    document.dispatchEvent(openEvent);

    // Listen for the confirm print event
    const confirmHandler = (event) => {
      console.log("Confirm print event received in print_form_controller!");
      document.removeEventListener("confirm-print-selected", confirmHandler);
      this.submitFormInternal();
    };
    document.addEventListener("confirm-print-selected", confirmHandler);
    console.log("Listener added for confirm-print-selected");
  }

  // Interceptar el submit del formulario para enviar a través del servicio serial
  async submitForm(event) {
    event.preventDefault();
    this.submitFormInternal();
  }

  // Internal method to submit the form without preventing default
  async submitFormInternal() {
    const currentWeight = parseFloat(this.weightFieldTarget.value);

    if (currentWeight <= 0) {
      this.showMessage("Debe capturar el peso antes de imprimir", "error");
      this.validatePrintButton();
      return false;
    }

    // Obtener datos del formulario
    const formElement =
      this.element.closest("form") || document.getElementById("print-form");
    const formData = new FormData(formElement);
    const printData = {
      product_name: formData.get("product_name") || "Producto",
      barcode_data: formData.get("barcode_data") || "",
      current_weight: currentWeight.toFixed(1),
      format_type: formData.get("format_type") || "bag",
      ancho_mm: formData.get("ancho_mm") || "80",
      alto_mm: formData.get("alto_mm") || "50",
      gap_mm: formData.get("gap_mm") || "2",
      // Campos específicos para formato bolsa
      bag_type: formData.get("bag_type") || "",
      bag_measurement: formData.get("bag_measurement") || "",
      pieces_count: formData.get("pieces_count") || "1",
      // Campos específicos para formato rollo
      roll_type: formData.get("roll_type") || "",
      roll_measurement: formData.get("roll_measurement") || "",
      pieces_count_roll: formData.get("pieces_count_roll") || "1",
      // Campos específicos para formato caja
      bag_type_box: formData.get("bag_type_box") || "",
      bag_measurement_box: formData.get("bag_measurement_box") || "",
      pieces_count_box: formData.get("pieces_count_box") || "1",
      package_count: formData.get("package_count") || "1",
      package_measurement: formData.get("package_measurement") || "",
    };

    // Generar contenido de etiqueta
    const labelContent = this.generateLabelContent(printData);

    // For debugging purposes, let's log the data to the console instead of actually printing
    console.log("Print data:", JSON.stringify(printData, null, 2));
    console.log("Label content:", labelContent);

    try {
      this.showMessage("Imprimiendo etiqueta...", "info");
      
      const response = await fetch('/admin/manual_printing/print_test', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify(printData)
      });
      
      const result = await response.json();
      
      if (result.success) {
        this.showMessage(`Etiqueta impresa: ${result.message}`, "success");
        console.log("Print success:", result);
      } else {
        throw new Error(result.message || "Error desconocido");
      }
    } catch (error) {
      console.error("Print error:", error);
      this.showMessage(
        `Error al imprimir: ${error.message}`,
        "error"
      );
    }

    return false;
  }

  // Generar contenido de etiqueta basado en el formato
  generateLabelContent(data) {
    const timestamp = new Date().toLocaleString();

    switch (data.format_type) {
      case "bag":
        return `${data.product_name}
Peso: ${data.current_weight}kg
Código: ${data.barcode_data}
Bolsa: ${data.bag_type || "No especificada"}
Medida: ${data.bag_measurement || "No especificada"}
Piezas: ${data.pieces_count || "1"}
${timestamp}`;

      case "roll":
        return `${data.product_name}
Peso: ${data.current_weight}kg
Código: ${data.barcode_data}
Rollo: ${data.roll_type || "No especificado"}
Medida: ${data.roll_measurement || "No especificada"}
Piezas: ${data.pieces_count_roll || "1"}
${timestamp}`;

      case "box":
        return `CAJA: ${data.product_name}
Peso Total: ${data.current_weight}kg
Barcode: ${data.barcode_data}
Bolsa: ${data.bag_type_box || "No especificada"}
Medida: ${data.bag_measurement_box || "No especificada"}
Piezas: ${data.pieces_count_box || "1"}
Paquetes: ${data.package_count || "1"} de ${
          data.package_measurement || "No especificadas"
        }
Fecha: ${timestamp}`;

      default:
        return `${data.product_name} - ${data.current_weight}kg - ${data.barcode_data}`;
    }
  }

  // Obtener referencia al controlador serial
  getSerialController() {
    const serialElement = document.querySelector('[data-controller*="serial"]');
    if (!serialElement) return null;

    return this.application.getControllerForElementAndIdentifier(
      serialElement,
      "serial"
    );
  }

  disconnect() {
    // Cleanup si es necesario
  }
}
