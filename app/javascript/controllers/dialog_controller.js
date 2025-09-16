import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop", "dialog"]

  connect() {
    this.isClosing = false
    this.lastClickTime = 0
    this.debounceDelay = 300 // 300ms debounce
    this.setupEventDelegation()
    this.element.addEventListener("dialog:close", this.close.bind(this))
    this.element.addEventListener("dialog:open", this.open.bind(this))
  }

  setupEventDelegation() {
    
    const dialogId = this.element.getAttribute("data-dialog-backdrop")
    
    // Use event delegation on document to avoid duplicate listeners
    // Remove any existing delegation first
    if (this.documentClickHandler) {
      document.removeEventListener("click", this.documentClickHandler)
    }
    
    this.documentClickHandler = (e) => {
      // Only ignore submit buttons, not all form elements
      if (e.target.type === 'submit' && !e.target.hasAttribute('data-dialog-close')) {
        return
      }
      
      const target = e.target.closest(`[data-dialog-target="${dialogId}"]`)
      if (target) {
        // Prevent opening if we're in the middle of closing
        if (this.isClosing) {
          e.preventDefault()
          return
        }
        
        // Check if modal is already open
        const isModalOpen = !this.element.classList.contains('opacity-0')
        if (isModalOpen) {
          e.preventDefault()
          return
        }
        
        // Debounce multiple rapid clicks
        const now = Date.now()
        if (now - this.lastClickTime < this.debounceDelay) {
          e.preventDefault()
          return
        }
        this.lastClickTime = now
        
        e.preventDefault()
        
        // Special handling for edit modal
        if (dialogId === "edit-consecutivo-modal") {
          // Get the URL from the clicked element
          const url = target.getAttribute("href")

          if (url) {
            // Store the URL for later use
            this.editUrl = url
            // Open the modal
            this.open()
          } else {
          }
        } else {
          // Regular modal opening for other modals
          this.open()
        }
        return
      }
      
      // Handle close buttons
      const closeButton = e.target.closest("[data-dialog-close]")
      if (closeButton && this.element.contains(closeButton)) {
        e.preventDefault()
        this.close()
        return
      }
    }
    
    document.addEventListener("click", this.documentClickHandler)

    // Handle backdrop clicks
    if (this.element.hasAttribute("data-dialog-backdrop-close")) {
      if (this.backdropClickHandler) {
        this.element.removeEventListener("click", this.backdropClickHandler)
      }
      
      this.backdropClickHandler = (e) => {
        if (e.target === this.element) {
          this.close()
        }
      }
      
      this.element.addEventListener("click", this.backdropClickHandler)
    }
  }

  disconnect() {
    // Clean up event listeners when controller is disconnected
    if (this.documentClickHandler) {
      document.removeEventListener("click", this.documentClickHandler)
    }
    if (this.backdropClickHandler) {
      this.element.removeEventListener("click", this.backdropClickHandler)
    }
    
    // Remove our custom event listeners
    this.element.removeEventListener("dialog:close", this.close.bind(this))
    this.element.removeEventListener("dialog:open", this.open.bind(this))
  }

  open() {
    this.element.classList.remove("pointer-events-none", "opacity-0")
    this.element.classList.add("pointer-events-auto", "opacity-100")
    document.body.style.overflow = "hidden"
    
    // Special handling for edit modal
    if (this.element.id === "edit-consecutivo-modal" && this.editUrl) {
      // Load the edit content after a short delay to ensure modal is visible
      setTimeout(() => {
        this.loadEditContent(this.editUrl)
      }, 100)
    } else {
    }
  }

  close() {
    this.isClosing = true
    this.element.classList.add("pointer-events-none", "opacity-0")
    this.element.classList.remove("pointer-events-auto", "opacity-100")
    document.body.style.overflow = ""
    
    // Update last click time to prevent immediate reopening
    this.lastClickTime = Date.now()
    
    // Reset closing flag after a longer delay
    setTimeout(() => {
      this.isClosing = false
    }, 1000) // Extended to 1 second
  }

  loadEditContent(url) {
    
    // Find the modal body container
    const modalBody = this.element.querySelector("#edit-consecutivo-modal-body")
    if (!modalBody) {
      return
    }
    
    
    // Show loading indicator
    modalBody.innerHTML = `
      <div class="flex justify-center items-center py-8">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-emerald-600"></div>
        <span class="ml-2 text-emerald-700">Cargando...</span>
      </div>
    `
    
    // Fetch the edit form content using Turbo's fetch method
    // This ensures proper handling of Rails responses
    const xhr = new XMLHttpRequest()
    xhr.open("GET", url)
    xhr.setRequestHeader("Accept", "text/html")
    
    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) {
        // Parse the response and extract the content
        const parser = new DOMParser()
        const doc = parser.parseFromString(xhr.responseText, "text/html")
        
        // Find the content we want to insert
        const content = doc.querySelector("#edit-consecutivo-modal-body")
        if (content) {
          modalBody.innerHTML = content.innerHTML
        } else {

          modalBody.innerHTML = `
            <div class="text-center py-8 text-red-600">
              <p>Error al cargar el formulario. Contenido no encontrado.</p>
              <button class="mt-4 px-4 py-2 bg-emerald-600 text-white rounded-md hover:bg-emerald-700"
                      onclick="location.reload()">
                Reintentar
              </button>
            </div>
          `
        }
      } else {
        modalBody.innerHTML = `
          <div class="text-center py-8 text-red-600">
            <p>Error al cargar el formulario. Código de error: ${xhr.status}</p>
            <button class="mt-4 px-4 py-2 bg-emerald-600 text-white rounded-md hover:bg-emerald-700"
                    onclick="location.reload()">
              Reintentar
            </button>
          </div>
        `
      }
    }
    
    xhr.onerror = () => {
      modalBody.innerHTML = `
        <div class="text-center py-8 text-red-600">
          <p>Error de red al cargar el formulario. Por favor, verifica tu conexión.</p>
          <button class="mt-4 px-4 py-2 bg-emerald-600 text-white rounded-md hover:bg-emerald-700"
                  onclick="location.reload()">
            Reintentar
          </button>
        </div>
      `
    }
    
    xhr.send()
  }

  // Method to be called from turbo streams
  closeModal() {
    this.close()
  }

  // Simple action to close modal that can be called via turbo stream action
  closeViaAction() {
    this.close()
    if (window.showToast) {
      window.showToast('success', '', 'Operación exitosa')
    }
  }
}