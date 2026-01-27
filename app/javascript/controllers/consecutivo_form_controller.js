import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "pesoNeto", "metrosLineales", "pesoBrutoInput", "pesoBrutoHidden",
    "pesoCoreDisplay", "pesoNetoDisplay", "metrosLinealesDisplay",
    "especificacionesDisplay", "manualModeCheckbox", "manualWeightSection",
    "scaleWeightSection", "serialSection", "backupWeighButton",
    "pesoBrutoManualHidden", "autoPrintCheckbox"
  ]

  connect() {
    this.instanceId = Math.random().toString(36).substr(2, 9);
    console.log(`[Consecutivo ${this.instanceId}] 🔌 Connect`);

    this.resetState()
    this.calculateWeights()
    this.listenForWeightUpdates()
  }

  // MutationObserver removed - Stimulus automatically handles disconnect/connect when DOM is replaced
  // The modal parent lookup was failing after the second print, causing controllers to not disconnect properly



  resetState() {
    console.log(`[Consecutivo ${this.instanceId}] 🔄 Resetting state`);
    this.currentWeight = null
    this.isManualMode = false
    this.lastWeights = []
    this.hasTriggered = false
    this.stabilityThreshold = 1 // Ajustado para lectura por pulso (un solo dato)
    this.stabilityRange = 0.1
    this.minWeight = 0.1
    this.waitingForWeightRemoval = false
    this.isFirstWeight = true
  }

  // Removed handleTurboStream - MutationObserver handles form replacement

  disconnect() {
    console.log(`[Consecutivo ${this.instanceId}] 🔌 Controller disconnecting | hasTriggered: ${this.hasTriggered} | waitingForRemoval: ${this.waitingForWeightRemoval}`);
    
    if (this.boundHandleWeightUpdate) {
      console.log(`[Consecutivo ${this.instanceId}] 🔇 Removing weight update event listener`);
      document.removeEventListener("serial:weight-update", this.boundHandleWeightUpdate);
    }
    
    if (this.boundHandleTurboStream) {
      console.log(`[Consecutivo ${this.instanceId}] 🔇 Removing Turbo Stream event listener`);
      document.removeEventListener('turbo:before-stream-render', this.boundHandleTurboStream);
    }
    
    this.removeStatusIndicator();
    
    // Clear any pending state
    console.log(`[Consecutivo ${this.instanceId}] 🧹 Clearing state flags in disconnect`);
    this.hasTriggered = false;
    this.waitingForWeightRemoval = false;
  }

  toggleManualMode(event) {
    this.isManualMode = event.target.checked
    if (this.isManualMode) {
      this.enableManualMode()
    } else {
      this.enableScaleMode()
    }
  }

  toggleAutoPrint(event) {
    const isChecked = event.target.checked;
    console.log(`[Consecutivo] 🔄 Guardando preferencia de impresión automática: ${isChecked}`);
    
    const formData = new FormData();
    formData.append('company[auto_save_consecutivo]', isChecked ? '1' : '0');
    
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
    
    fetch('/admin/configurations/auto_save', {
      method: 'PATCH',
      headers: {
        'X-CSRF-Token': csrfToken,
        'Accept': 'application/json'
      },
      body: formData
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        console.log('[Consecutivo] ✅ Preferencia guardada exitosamente');
      } else {
        console.error('[Consecutivo] ❌ Error al guardar preferencia:', data.message);
      }
    })
    .catch(error => {
      console.error('[Consecutivo] ❌ Error de red al guardar preferencia:', error);
    });
  }

  enableManualMode() {
    if (this.hasManualWeightSectionTarget) this.manualWeightSectionTarget.classList.remove('hidden')
    if (this.hasScaleWeightSectionTarget) {
      const scaleMsg = this.scaleWeightSectionTarget.querySelector('.scale-mode-message')
      const manualMsg = this.scaleWeightSectionTarget.querySelector('.manual-mode-message')
      if (scaleMsg) scaleMsg.classList.add('hidden')
      if (manualMsg) manualMsg.classList.remove('hidden')
    }
    if (this.hasSerialSectionTarget) this.serialSectionTarget.classList.add('hidden')
    if (this.hasPesoBrutoInputTarget) {
      this.pesoBrutoInputTarget.disabled = false
      this.pesoBrutoInputTarget.classList.replace('bg-gray-100', 'bg-slate-50')
    }
    if (this.hasBackupWeighButtonTarget) {
      this.backupWeighButtonTarget.disabled = false
      this.backupWeighButtonTarget.classList.remove('bg-gray-400', 'cursor-not-allowed')
      this.backupWeighButtonTarget.classList.add('bg-blue-600', 'hover:bg-blue-700')
    }
  }

  enableScaleMode() {
    if (this.hasManualWeightSectionTarget) this.manualWeightSectionTarget.classList.add('hidden')
    if (this.hasScaleWeightSectionTarget) {
      const scaleMsg = this.scaleWeightSectionTarget.querySelector('.scale-mode-message')
      const manualMsg = this.scaleWeightSectionTarget.querySelector('.manual-mode-message')
      if (scaleMsg) scaleMsg.classList.remove('hidden')
      if (manualMsg) manualMsg.classList.add('hidden')
    }
    if (this.hasSerialSectionTarget) this.serialSectionTarget.classList.remove('hidden')
    if (this.hasPesoBrutoInputTarget) {
      this.pesoBrutoInputTarget.disabled = true
      this.pesoBrutoInputTarget.classList.replace('bg-slate-50', 'bg-gray-100')
      this.pesoBrutoInputTarget.value = ''
    }
    if (this.hasBackupWeighButtonTarget) {
      this.backupWeighButtonTarget.disabled = true
      this.backupWeighButtonTarget.classList.add('bg-gray-400', 'cursor-not-allowed')
      this.backupWeighButtonTarget.classList.remove('bg-blue-600', 'hover:bg-blue-700')
    }
    this.calculateWeights()
  }

  listenForWeightUpdates() {
    this.boundHandleWeightUpdate = (event) => {
      this.onWeightRead(event);
    }
    document.addEventListener('serial:weight-update', this.boundHandleWeightUpdate);
  }

  onWeightRead(event) {
    const weight = parseFloat(event.detail.weight);
    // console.log(`[Consecutivo ${this.instanceId}] ⚖️ Read: ${weight}kg`);
    this.currentWeight = weight;
    
    this.calculateWeights();
    this.checkStabilityAndTrigger(this.currentWeight);
  }

  checkStabilityAndTrigger(weightValue) {
    if (weightValue < this.minWeight) {
      if (this.waitingForWeightRemoval) {
        console.log(`[Consecutivo ${this.instanceId}] ⚖️ Peso removido. Listo para siguiente.`);
        this.removeStatusIndicator();
        this.resetState();
      } else {
        this.currentWeight = weightValue;
      }
      return;
    }

    // Solo procesar si no hemos disparado aún y no estamos esperando la remoción del peso
    if (this.hasTriggered || this.waitingForWeightRemoval) {
      this.currentWeight = weightValue;
      return;
    }

    this.lastWeights.push(weightValue);
    if (this.lastWeights.length > this.stabilityThreshold) this.lastWeights.shift();

    if (this.lastWeights.length === this.stabilityThreshold) {
      const min = Math.min(...this.lastWeights);
      const max = Math.max(...this.lastWeights);
      const variance = max - min;

      if (variance <= this.stabilityRange) {
        const isAutoPrintEnabled = this.hasAutoPrintCheckboxTarget && this.autoPrintCheckboxTarget.checked;
        
        if (isAutoPrintEnabled) {
          console.log(`[Consecutivo ${this.instanceId}] ✅ Pulso ${weightValue}kg. Guardando...`);
          this.hasTriggered = true;
          this.waitingForWeightRemoval = true;
          this.showStatusHint(`✅ Pulso detectado (${weightValue.toFixed(2)}kg) - Guardando...`, "bg-emerald-600", true);

          setTimeout(() => {
            const form = this.element.closest('form') || this.element;
            if (form) form.requestSubmit();
          }, 300);
        }
      }
    }
  }

  showStatusHint(message, bgColor, showSpinner = false) {
    this.removeStatusIndicator();
    const indicator = document.createElement('div');
    indicator.id = 'auto-submit-indicator';
    indicator.className = `fixed bottom-10 right-10 ${bgColor} text-white px-6 py-3 rounded-xl shadow-2xl z-[10000] flex items-center gap-3 animate-in fade-in zoom-in duration-300 transform scale-110`;
    
    let icon = '';
    if (showSpinner) {
      icon = `<svg class="animate-spin h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>`;
    } else {
      icon = `<svg class="h-5 w-5 text-white animate-bounce" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 14l-7 7m0 0l-7-7m7 7V3" />
              </svg>`;
    }

    indicator.innerHTML = `${icon}<span class="font-bold text-lg">${message}</span>`;
    document.body.appendChild(indicator);
  }

  removeStatusIndicator() {
    const indicator = document.getElementById('auto-submit-indicator');
    if (indicator) indicator.remove();
  }

  calculateWeights() {
    let pesoBruto = 0;
    if (this.isManualMode && this.hasPesoBrutoInputTarget) {
      const val = parseFloat(this.pesoBrutoInputTarget.value);
      pesoBruto = isNaN(val) ? 0 : val;
    } else if (this.currentWeight !== null) {
      pesoBruto = isNaN(this.currentWeight) ? 0 : this.currentWeight;
    } else if (this.hasPesoBrutoHiddenTarget) {
      const val = parseFloat(this.pesoBrutoHiddenTarget.value);
      pesoBruto = isNaN(val) ? 0 : val;
    }
    
    const alturaVal = parseFloat(this.getFieldValue("altura_cm"));
    const alturaCm = isNaN(alturaVal) ? 75 : alturaVal;
    const { micras, anchoMm } = this.extractMicrasAndWidth()
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

    this.updateCalculatedFields(pesoNeto, metrosLineales, pesoCoreGramos, micras, anchoMm, pesoBruto)
  }

  updateCalculatedFields(pesoNeto, metrosLineales, pesoCoreGramos, micras, anchoMm, pesoBruto) {
    if (this.hasPesoNetoTarget) this.pesoNetoTarget.value = pesoNeto.toFixed(3)
    if (this.hasMetrosLinealesTarget) this.metrosLinealesTarget.value = metrosLineales.toFixed(4)
    if (this.hasPesoNetoDisplayTarget) this.pesoNetoDisplayTarget.textContent = `${pesoNeto.toFixed(3)} kg`
    if (this.hasMetrosLinealesDisplayTarget) this.metrosLinealesDisplayTarget.textContent = `${metrosLineales.toFixed(4)} m`
    if (this.hasPesoCoreDisplayTarget) this.pesoCoreDisplayTarget.textContent = `${pesoCoreGramos} g`
    if (this.hasEspecificacionesDisplayTarget) this.especificacionesDisplayTarget.textContent = `${micras}μ / ${anchoMm}mm`
    if (this.hasPesoBrutoHiddenTarget && pesoBruto !== undefined) this.pesoBrutoHiddenTarget.value = pesoBruto.toFixed(2)

    this.setFieldValue("peso_neto", pesoNeto.toFixed(3))
    this.setFieldValue("metros_lineales", metrosLineales.toFixed(4))
    this.setFieldValue("peso_core_gramos", pesoCoreGramos)
    if (micras > 0) this.setFieldValue("micras", micras)
    if (anchoMm > 0) this.setFieldValue("ancho_mm", anchoMm)
  }

  extractMicrasAndWidth() {
    const claveProducto = this.getFieldValue("clave_producto_display") || 
                         document.getElementById("clave_producto")?.value || ""
    const matches = claveProducto.match(/(\d+)\s*\/\s*(\d+)/)
    if (matches) {
      return { micras: parseInt(matches[1]) || 35, anchoMm: parseInt(matches[2]) || 420 }
    }
    return { micras: 35, anchoMm: 420 }
  }

  findClosestCoreWeight(altura, table) {
    const keys = Object.keys(table).map(k => parseInt(k)).sort((a, b) => a - b)
    if (altura <= keys[0]) return table[keys[0]]
    if (altura >= keys[keys.length - 1]) return table[keys[keys.length - 1]]
    for (let i = 0; i < keys.length - 1; i++) {
      if (altura >= keys[i] && altura < keys[i + 1]) return table[keys[i]]
    }
    return table[keys[keys.length - 1]]
  }

  getFieldValue(fieldName) {
    if (fieldName === "peso_bruto") {
      if (this.isManualMode && this.hasPesoBrutoInputTarget) return this.pesoBrutoInputTarget.value;
      if (this.currentWeight !== null) return this.currentWeight.toString();
      if (this.hasPesoBrutoHiddenTarget) return this.pesoBrutoHiddenTarget.value;
    }
    const field = this.element.querySelector(`[name*="${fieldName}"]`) || 
                  this.element.querySelector(`input[id*="${fieldName}"]`)
    return field ? field.value : ""
  }

  setFieldValue(fieldName, value) {
    const field = this.element.querySelector(`[name*="${fieldName}"]`) || 
                  this.element.querySelector(`input[id*="${fieldName}"]`)
    if (field) field.value = value
  }

  handleFormSubmit(event) {
    console.log(`[Consecutivo ${this.instanceId}] 📝 Form submit handler called`);
    this.calculateWeights()
    if (this.isManualMode && this.hasPesoBrutoInputTarget && this.hasPesoBrutoHiddenTarget) {
      this.pesoBrutoHiddenTarget.value = this.pesoBrutoInputTarget.value || "0"
    } else if (this.currentWeight !== null && this.hasPesoBrutoHiddenTarget) {
      this.pesoBrutoHiddenTarget.value = this.currentWeight.toString()
    }
    
    // Don't reset state here - let the controller lifecycle handle it
    // The Turbo Stream will replace the form, triggering disconnect() then connect()
  }
}
