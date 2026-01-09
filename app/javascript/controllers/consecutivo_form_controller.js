import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pesoNeto", "metrosLineales", "pesoBrutoInput", "pesoBrutoHidden", "pesoCoreDisplay", "pesoNetoDisplay", "metrosLinealesDisplay", "especificacionesDisplay", "manualModeCheckbox", "manualWeightSection", "scaleWeightSection", "serialSection", "backupWeighButton", "pesoBrutoManualHidden", "autoPrintCheckbox"]

  connect() {
    console.log("Consecutivo form controller connected")
    this.calculateWeights()
    this.currentWeight = null
    this.listenForWeightUpdates()
    this.isManualMode = false
    this.lastWeights = []
    this.hasTriggered = false
    this.stabilityThreshold = 3
    this.stabilityRange = 0.05
    this.minWeight = 0.2
    this.waitingForWeightRemoval = false
    this.isFirstWeight = true
    
    // Escuchar el nuevo evento de peso actualizado desde la báscula
    this.element.addEventListener('scale:weightUpdated', (event) => {
      console.log('Received scale:weightUpdated event:', event.detail);
      this.currentWeight = parseFloat(event.detail.weight);
      this.calculateWeights(); // Trigger calculations
    });
  }

  toggleManualMode(event) {
    this.isManualMode = event.target.checked
    
    if (this.isManualMode) {
      this.enableManualMode()
    } else {
      this.enableScaleMode()
    }
  }

  enableManualMode() {
    // Mostrar sección de input manual
    if (this.hasManualWeightSectionTarget) {
      this.manualWeightSectionTarget.classList.remove('hidden')
    }
    
    // Cambiar visibilidad de los mensajes
    if (this.hasScaleWeightSectionTarget) {
      const scaleMessage = this.scaleWeightSectionTarget.querySelector('.scale-mode-message')
      const manualMessage = this.scaleWeightSectionTarget.querySelector('.manual-mode-message')
      
      if (scaleMessage) {
        scaleMessage.classList.add('hidden')
      }
      if (manualMessage) {
        manualMessage.classList.remove('hidden')
      }
    }
    
    // Ocultar sección de pesaje serial
    if (this.hasSerialSectionTarget) {
      this.serialSectionTarget.classList.add('hidden')
    }
    
    // Habilitar input de peso
    if (this.hasPesoBrutoInputTarget) {
      this.pesoBrutoInputTarget.disabled = false
      this.pesoBrutoInputTarget.classList.remove('bg-gray-100')
      this.pesoBrutoInputTarget.classList.add('bg-slate-50')
    }
    
    // Habilitar botón backup
    if (this.hasBackupWeighButtonTarget) {
      this.backupWeighButtonTarget.disabled = false
      this.backupWeighButtonTarget.classList.remove('bg-gray-400', 'cursor-not-allowed')
      this.backupWeighButtonTarget.classList.add('bg-blue-600', 'hover:bg-blue-700', 'shadow-md', 'hover:shadow-lg')
    }
  }

  enableScaleMode() {
    // Ocultar sección de input manual
    if (this.hasManualWeightSectionTarget) {
      this.manualWeightSectionTarget.classList.add('hidden')
    }
    
    // Cambiar visibilidad de los mensajes
    if (this.hasScaleWeightSectionTarget) {
      const scaleMessage = this.scaleWeightSectionTarget.querySelector('.scale-mode-message')
      const manualMessage = this.scaleWeightSectionTarget.querySelector('.manual-mode-message')
      
      if (scaleMessage) {
        scaleMessage.classList.remove('hidden')
      }
      if (manualMessage) {
        manualMessage.classList.add('hidden')
      }
    }
    
    // Mostrar sección de pesaje serial
    if (this.hasSerialSectionTarget) {
      this.serialSectionTarget.classList.remove('hidden')
    }
    
    // Deshabilitar input de peso (modo báscula)
    if (this.hasPesoBrutoInputTarget) {
      this.pesoBrutoInputTarget.disabled = true
      this.pesoBrutoInputTarget.classList.add('bg-gray-100')
      this.pesoBrutoInputTarget.classList.remove('bg-slate-50')
      // Limpiar el valor cuando se cambia a modo báscula
      this.pesoBrutoInputTarget.value = ''
      this.calculateWeights() // Recalcular con peso 0
    }
    
    // Deshabilitar botón backup
    if (this.hasBackupWeighButtonTarget) {
      this.backupWeighButtonTarget.disabled = true
      this.backupWeighButtonTarget.classList.add('bg-gray-400', 'cursor-not-allowed')
      this.backupWeighButtonTarget.classList.remove('bg-blue-600', 'hover:bg-blue-700', 'shadow-md', 'hover:shadow-lg')
    }
  }

  // Escuchar eventos del controlador serial
  listenForWeightUpdates() {
    // Escuchar el evento antiguo serial:weightRead
    this.element.addEventListener('serial:weightRead', (event) => {
      console.log('Received serial:weightRead event:', event.detail);
      this.onWeightRead(event);
    });
  }

  // Método público para manejar evento serial:weightRead
  onWeightRead(event) {
    // Extraer el peso del evento
    const weight = event.detail.weight;
    this.currentWeight = parseFloat(weight);
    
    if (this.isFirstWeight) {
      this.isFirstWeight = false;
      // If weight is already present when connecting, we must wait for it to be removed
      // to avoid double triggering the same item that was just saved
      if (this.currentWeight > this.minWeight) {
        console.log("Weight detected on start, waiting for removal");
        this.waitingForWeightRemoval = true;
      }
    }

    console.log('Weight received and stored:', this.currentWeight);
    this.calculateWeights(); // Trigger calculations
    
    // New stability detection logic
    this.checkStabilityAndTrigger(this.currentWeight);
  }

  checkStabilityAndTrigger(weightValue) {
    // 1. Handle trigger reset when weight removed
    if (weightValue < this.minWeight) {
      if (this.hasTriggered || this.waitingForWeightRemoval) {
        console.log("Weight removed or below threshold, ready for next item");
      }
      this.hasTriggered = false;
      this.waitingForWeightRemoval = false;
      this.lastWeights = [];
      return;
    }

    // 2. Already triggered for this item or waiting for removal?
    if (this.hasTriggered || this.waitingForWeightRemoval) return;

    // 3. Track last weights
    this.lastWeights.push(weightValue);
    if (this.lastWeights.length > this.stabilityThreshold) {
      this.lastWeights.shift();
    }

    // 4. Check if we have enough readings and they are stable
    if (this.lastWeights.length === this.stabilityThreshold) {
      const min = Math.min(...this.lastWeights);
      const max = Math.max(...this.lastWeights);
      const variance = max - min;

      if (variance <= this.stabilityRange && weightValue >= this.minWeight) {
        console.log(`Stability reached: ${weightValue}kg. Checking auto-print...`);
        
        const isAutoPrintEnabled = this.hasAutoPrintCheckboxTarget && this.autoPrintCheckboxTarget.checked;

        if (isAutoPrintEnabled) {
          console.log("Triggering auto-save and print from form controller!");
          this.hasTriggered = true;
          this.showAutoSubmitStatus(weightValue);
          
          // Use a small delay for visual feedback before submitting
          setTimeout(() => {
            // Find submit button and click it for guaranteed Turbo behavior
            const submitBtn = this.element.querySelector('input[type="submit"]') || 
                              this.element.querySelector('button[type="submit"]');
            
            if (submitBtn) {
              submitBtn.click();
            } else {
              this.element.requestSubmit();
            }
          }, 500);
        }
      }
    }
  }

  showAutoSubmitStatus(weight) {
    // Show a temporary indicator that we are saving
    const statusDiv = document.createElement('div');
    statusDiv.id = 'auto-submit-indicator';
    statusDiv.className = 'fixed bottom-4 right-4 bg-emerald-600 text-white px-4 py-2 rounded-lg shadow-lg z-50 flex items-center gap-2 animate-bounce';
    statusDiv.innerHTML = `
      <svg class="animate-spin h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      <span>Estable (${weight.toFixed(2)}kg) - Guardando...</span>
    `;
    document.body.appendChild(statusDiv);
    
    // Disable submit button manually to avoid double clicks
    const submitBtn = this.element.querySelector('input[type="submit"]') || 
                      this.element.querySelector('button[type="submit"]');
    if (submitBtn) {
      submitBtn.disabled = true;
      submitBtn.classList.add('opacity-50', 'cursor-not-allowed');
      submitBtn.textContent = 'Guardando...';
    }
  }

  // Actualizar visualización del peso en el display
  updateWeightDisplay(weight) {
    // Crear un indicador visual del peso aplicado
    const indicator = document.createElement('div')
    indicator.className = 'text-xs text-emerald-600 font-medium mt-2'
    indicator.textContent = `Peso aplicado: ${weight} kg`
    indicator.id = 'weight-applied-indicator'
    
    // Remover indicador anterior si existe
    const existing = document.getElementById('weight-applied-indicator')
    if (existing) {
      existing.remove()
    }
    
    // Agregar indicador después del panel de cálculos
    const calculosPanel = this.element.querySelector('.bg-emerald-50')
    if (calculosPanel) {
      calculosPanel.appendChild(indicator)
    }
  }

  // Calcular pesos con un valor específico (para modo báscula)
  calculateWeightsWithValue(pesoBrutoValue) {
    const pesoBruto = parseFloat(pesoBrutoValue) || 0
    const alturaCm = parseFloat(this.getFieldValue("altura_cm")) || 75
    const { micras, anchoMm } = this.extractMicrasAndWidth()

    // Usar la misma lógica de cálculo pero con el valor específico
    const coreWeightTable = {
      0: 0, 70: 200, 80: 200, 90: 200, 100: 200, 110: 200, 120: 200, 
      124: 200, 130: 200, 140: 200, 142: 200, 143: 200, 150: 200, 
      160: 200, 170: 200, 180: 200, 190: 400, 200: 400, 210: 400, 
      220: 400, 230: 400, 240: 500, 250: 500, 260: 500, 270: 500, 
      280: 500, 290: 600, 300: 600, 310: 600, 320: 600, 330: 600, 
      340: 700, 350: 700, 360: 700, 370: 700, 380: 700, 390: 700, 
      400: 800, 410: 800, 420: 800, 430: 800, 440: 900, 450: 900, 
      460: 900, 470: 900, 480: 900, 490: 1000, 500: 1000, 510: 1000, 
      520: 1000, 530: 1000, 540: 1100, 550: 1100, 560: 1100, 570: 1100, 
      580: 1100, 590: 1200, 600: 1200, 610: 1200, 620: 1200, 630: 1200, 
      640: 1300, 650: 1300, 660: 1300, 670: 1300, 680: 1300, 690: 1400, 
      700: 1400, 710: 1400, 720: 1400, 730: 1400, 740: 1500, 750: 1500, 
      760: 1500, 770: 1500, 780: 1500, 790: 1600, 800: 1600, 810: 1600, 
      820: 1600, 830: 1600, 840: 1700, 850: 1700, 860: 1700, 870: 1700, 
      880: 1700, 890: 1800, 900: 1800, 910: 1800, 920: 1800, 930: 1800, 
      940: 1900, 950: 1900, 960: 1900, 970: 1900, 980: 1900, 990: 2000, 
      1000: 2000, 1020: 2000, 1040: 1200, 1050: 1200, 1060: 1200, 
      1100: 2200, 1120: 2200, 1140: 2300, 1160: 2300, 1180: 2400, 
      1200: 2400, 1220: 2400, 1240: 2500, 1250: 2500, 1260: 2600, 
      1300: 2600, 1320: 2600, 1340: 2700, 1360: 2700, 1400: 2800
    }

    const pesoCoreGramos = this.findClosestCoreWeight(alturaCm, coreWeightTable)
    let pesoNeto = pesoBruto - (pesoCoreGramos / 1000.0)
    pesoNeto = Math.max(0, pesoNeto)
    
    let metrosLineales = 0
    if (pesoNeto > 0 && micras > 0 && anchoMm > 0) {
      metrosLineales = (pesoNeto * 1000000) / micras / anchoMm / 0.92
      metrosLineales = Math.max(0, metrosLineales)
    }

    // Actualizar displays y campos hidden
    this.updateCalculatedFields(pesoNeto, metrosLineales, pesoCoreGramos, micras, anchoMm)
  }

  // Función auxiliar para actualizar campos calculados
  updateCalculatedFields(pesoNeto, metrosLineales, pesoCoreGramos, micras, anchoMm, pesoBruto) {
    // Actualizar campos hidden para formulario
    if (this.hasPesoNetoTarget) {
      this.pesoNetoTarget.value = pesoNeto.toFixed(3)
    }
    
    if (this.hasMetrosLinealesTarget) {
      this.metrosLinealesTarget.value = metrosLineales.toFixed(4)
    }

    // Actualizar displays visuales
    if (this.hasPesoNetoDisplayTarget) {
      this.pesoNetoDisplayTarget.textContent = `${pesoNeto.toFixed(3)} kg`
    }

    if (this.hasMetrosLinealesDisplayTarget) {
      this.metrosLinealesDisplayTarget.textContent = `${metrosLineales.toFixed(4)} m`
    }

    if (this.hasPesoCoreDisplayTarget) {
      this.pesoCoreDisplayTarget.textContent = `${pesoCoreGramos} g`
    }

    if (this.hasEspecificacionesDisplayTarget) {
      this.especificacionesDisplayTarget.textContent = `${micras}μ / ${anchoMm}mm`
    }

    // Actualizar peso bruto en el campo oculto
    if (this.hasPesoBrutoHiddenTarget && pesoBruto !== undefined) {
      this.pesoBrutoHiddenTarget.value = pesoBruto.toFixed(2)
    }

    // Actualizar campos ocultos para envío del formulario
    this.setFieldValue("peso_neto", pesoNeto.toFixed(3))
    this.setFieldValue("metros_lineales", metrosLineales.toFixed(4))
    this.setFieldValue("peso_core_gramos", pesoCoreGramos)
    
    if (micras > 0) {
      this.setFieldValue("micras", micras)
    }
    if (anchoMm > 0) {
      this.setFieldValue("ancho_mm", anchoMm)
    }
  }

  calculateWeights() {
    let pesoBruto = 0;
    
    // Get peso_bruto value based on mode
    if (this.isManualMode && this.hasPesoBrutoInputTarget) {
      // In manual mode, get value from the visible input
      pesoBruto = parseFloat(this.pesoBrutoInputTarget.value) || 0;
    } else if (this.currentWeight !== null) {
      // In scale mode, use the current weight from the scale
      pesoBruto = this.currentWeight;
    } else if (this.hasPesoBrutoHiddenTarget) {
      // Fallback to hidden field value
      pesoBruto = parseFloat(this.pesoBrutoHiddenTarget.value) || 0;
    }
    
    this.calculateWeightsWithValue(pesoBruto);
  }

  // Extraer micras y ancho mm desde clave producto (ej: "BOPPTRANS 35 / 420")
  extractMicrasAndWidth() {
    const claveProducto = this.getFieldValue("clave_producto_display") || 
                         document.getElementById("clave_producto")?.value || 
                         "BOPPTRANS 35 / 420"
    
    // Regex para extraer números: "BOPPTRANS 35 / 420" -> [35, 420]
    const matches = claveProducto.match(/(\d+)\s*\/\s*(\d+)/)
    
    if (matches) {
      const micras = parseInt(matches[1]) || 35
      const anchoMm = parseInt(matches[2]) || 420
      return { micras, anchoMm }
    }
    
    // Values por defecto si no se puede extraer
    return { micras: 35, anchoMm: 420 }
  }

  // Encontrar el peso core más cercano en la tabla
  findClosestCoreWeight(altura, table) {
    const keys = Object.keys(table).map(k => parseInt(k)).sort((a, b) => a - b)
    
    // Si la altura es menor que el primer valor, usar el primer peso
    if (altura <= keys[0]) {
      return table[keys[0]]
    }
    
    // Si la altura es mayor que el último valor, usar el último peso
    if (altura >= keys[keys.length - 1]) {
      return table[keys[keys.length - 1]]
    }
    
    // Encontrar el valor más cercano
    for (let i = 0; i < keys.length - 1; i++) {
      if (altura >= keys[i] && altura < keys[i + 1]) {
        return table[keys[i]]
      }
    }
    
    return table[keys[keys.length - 1]]
  }

  getFieldValue(fieldName) {
    // Special handling for peso_bruto to get from the visible input field
    if (fieldName === "peso_bruto") {
      // In manual mode, get value from the manual input field
      if (this.isManualMode && this.hasPesoBrutoInputTarget) {
        return this.pesoBrutoInputTarget.value;
      }
      // In scale mode, get value from the hidden field or current weight
      else if (this.currentWeight !== null) {
        return this.currentWeight.toString();
      } else if (this.hasPesoBrutoHiddenTarget) {
        return this.pesoBrutoHiddenTarget.value;
      }
    }
    
    const field = this.element.querySelector(`[name*="${fieldName}"]`) || 
                  this.element.querySelector(`input[id*="${fieldName}"]`)
    return field ? field.value : ""
  }

  setFieldValue(fieldName, value) {
    const field = this.element.querySelector(`[name*="${fieldName}"]`) || 
                  this.element.querySelector(`input[id*="${fieldName}"]`)
    if (field) {
      field.value = value
    }
  }

  // Handle form submission
  handleFormSubmit(event) {
    // Ensure calculations are up to date before submitting
    this.calculateWeights();
    
    // Make sure the hidden peso_bruto field has the correct value
    if (this.isManualMode && this.hasPesoBrutoInputTarget && this.hasPesoBrutoHiddenTarget) {
      this.pesoBrutoHiddenTarget.value = this.pesoBrutoInputTarget.value || "0";
    } else if (this.currentWeight !== null && this.hasPesoBrutoHiddenTarget) {
      this.pesoBrutoHiddenTarget.value = this.currentWeight.toString();
    }
    
    // Allow the form to submit normally via Turbo
    console.log('Form is being submitted via Turbo');
    
    // Log form data for debugging
    const form = event.target;
    if (form) {
      const formData = new FormData(form);
      console.log('Form submission data:');
      for (let [key, value] of formData.entries()) {
        console.log(`${key}: ${value}`);
      }
    }
    
    // Important: Do NOT call event.preventDefault() - let Turbo handle the submission
  }
}