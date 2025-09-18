import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "resultIcon", "resultTitle", "resultMessage", "testConnectionBtn", "checkChangesBtn"]
  
  connect() {
    // Set up modal close event
    if (this.hasModalTarget) {
      this.modalTarget.addEventListener('click', (e) => {
        if (e.target === this.modalTarget) {
          this.closeModal()
        }
      })
    }
  }
  
  async testConnection(event) {
    event.preventDefault()
    
    const btn = this.testConnectionBtnTarget
    const originalText = btn.textContent
    btn.disabled = true
    btn.textContent = 'Probando...'
    
    try {
      const response = await fetch('/admin/configurations/test_connection', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector("meta[name='csrf-token']").content,
          'Content-Type': 'application/json',
        }
      })
      
      const data = await response.json()
      this.showResult(data.success, data.message, data.success ? 'Conexión Exitosa' : 'Error de Conexión')
    } catch (error) {
      this.showResult(false, 'Error de conexión: ' + error.message, 'Error de Conexión')
    } finally {
      btn.disabled = false
      btn.textContent = originalText
    }
  }
  
  async checkChanges(event) {
    event.preventDefault()
    
    const btn = this.checkChangesBtnTarget
    const originalText = btn.textContent
    btn.disabled = true
    btn.textContent = 'Verificando...'
    
    try {
      const response = await fetch('/admin/configurations/check_changes', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector("meta[name='csrf-token']").content,
          'Content-Type': 'application/json',
        }
      })
      
      const data = await response.json()
      
      if (data.success) {
        let message = `${data.message}: ${data.details}`
        if (data.current_rows) {
          message += ` (${data.current_rows} filas)`
        }
        if (data.last_sync) {
          message += ` - Última sync: ${data.last_sync}`
        }
        
        this.showResult(data.has_changes, message, data.has_changes ? 'Cambios Detectados' : 'Sin Cambios')
      } else {
        this.showResult(false, data.message, 'Error')
      }
    } catch (error) {
      this.showResult(false, 'Error verificando cambios: ' + error.message, 'Error')
    } finally {
      btn.disabled = false
      btn.textContent = originalText
    }
  }
  
  showResult(success, message, title = null) {
    if (!this.hasResultIconTarget || !this.hasResultTitleTarget || !this.hasResultMessageTarget) return
    
    if (success) {
      this.resultIconTarget.innerHTML = '<svg class="h-6 w-6 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>'
      this.resultIconTarget.className = 'mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-green-100 mb-4'
      this.resultTitleTarget.textContent = title || 'Operación Exitosa'
    } else {
      this.resultIconTarget.innerHTML = '<svg class="h-6 w-6 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>'
      this.resultIconTarget.className = 'mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-red-100 mb-4'
      this.resultTitleTarget.textContent = title || 'Error'
    }
    this.resultMessageTarget.textContent = message
    this.modalTarget.classList.remove('hidden')
  }
  
  closeModal() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add('hidden')
    }
  }
}