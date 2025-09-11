import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["backdrop", "dialog"]

  connect() {
    console.log("Dialog controller connected")
    this.isClosing = false
    this.lastClickTime = 0
    this.debounceDelay = 300 // 300ms debounce
    this.setupEventDelegation()
    this.element.addEventListener("dialog:close", this.close.bind(this))
    this.element.addEventListener("dialog:open", this.open.bind(this))
  }

  setupEventDelegation() {
    console.log("Setting up event delegation for dialog")
    
    const dialogId = this.element.getAttribute("data-dialog-backdrop")
    console.log("Dialog ID:", dialogId)
    
    // Use event delegation on document to avoid duplicate listeners
    // Remove any existing delegation first
    if (this.documentClickHandler) {
      document.removeEventListener("click", this.documentClickHandler)
    }
    
    this.documentClickHandler = (e) => {
      // Only ignore submit buttons, not all form elements
      if (e.target.type === 'submit' && !e.target.hasAttribute('data-dialog-close')) {
        console.log("Ignoring click from submit button")
        return
      }
      
      const target = e.target.closest(`[data-dialog-target="${dialogId}"]`)
      if (target) {
        // Prevent opening if we're in the middle of closing
        if (this.isClosing) {
          console.log("Ignoring trigger click - modal is closing")
          e.preventDefault()
          return
        }
        
        // Check if modal is already open
        const isModalOpen = !this.element.classList.contains('opacity-0')
        if (isModalOpen) {
          console.log("Ignoring trigger click - modal already open")
          e.preventDefault()
          return
        }
        
        // Debounce multiple rapid clicks
        const now = Date.now()
        if (now - this.lastClickTime < this.debounceDelay) {
          console.log("Ignoring trigger click - too rapid (debounced)")
          e.preventDefault()
          return
        }
        this.lastClickTime = now
        
        e.preventDefault()
        console.log("Trigger clicked via delegation, opening dialog")
        
        // Special handling for edit modal
        if (dialogId === "edit-consecutivo-modal") {
          // Get the URL from the clicked element
          const url = target.getAttribute("href")
          console.log("Setting edit URL:", url)
          console.log("Target element:", target)
          if (url) {
            // Store the URL for later use
            this.editUrl = url
            // Open the modal
            this.open()
          } else {
            console.error("No URL found on target element")
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
        console.log("Close button clicked via delegation")
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
          console.log("Backdrop clicked, closing dialog")
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
    console.log("Opening dialog, element ID:", this.element.id)
    this.element.classList.remove("pointer-events-none", "opacity-0")
    this.element.classList.add("pointer-events-auto", "opacity-100")
    document.body.style.overflow = "hidden"
    
    // Special handling for edit modal
    if (this.element.id === "edit-consecutivo-modal" && this.editUrl) {
      console.log("Loading edit content for URL:", this.editUrl)
      // Load the edit content after a short delay to ensure modal is visible
      setTimeout(() => {
        this.loadEditContent(this.editUrl)
      }, 100)
    } else {
      console.log("Not loading edit content. Element ID match:", this.element.id === "edit-consecutivo-modal", "Has editUrl:", !!this.editUrl)
    }
  }

  close() {
    console.log("Closing dialog")
    this.isClosing = true
    this.element.classList.add("pointer-events-none", "opacity-0")
    this.element.classList.remove("pointer-events-auto", "opacity-100")
    document.body.style.overflow = ""
    
    // Update last click time to prevent immediate reopening
    this.lastClickTime = Date.now()
    
    // Reset closing flag after a longer delay
    setTimeout(() => {
      this.isClosing = false
      console.log("Dialog closing flag reset")
    }, 1000) // Extended to 1 second
  }

  loadEditContent(url) {
    console.log("Loading edit content from:", url)
    
    // Find the modal body container
    const modalBody = this.element.querySelector("#edit-consecutivo-modal-body")
    if (!modalBody) {
      console.error("Edit modal body not found")
      return
    }
    
    console.log("Modal body found, loading content...")
    
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
      console.log("XHR loaded, status:", xhr.status)
      if (xhr.status >= 200 && xhr.status < 300) {
        console.log("XHR successful, response length:", xhr.responseText.length)
        // Parse the response and extract the content
        const parser = new DOMParser()
        const doc = parser.parseFromString(xhr.responseText, "text/html")
        
        // Find the content we want to insert
        const content = doc.querySelector("#edit-consecutivo-modal-body")
        if (content) {
          console.log("Content found, updating modal body")
          modalBody.innerHTML = content.innerHTML
        } else {
          console.error("Could not find #edit-consecutivo-modal-body in response")
          console.log("Response preview:", xhr.responseText.substring(0, 500))
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
        console.error("Error loading edit content. Status:", xhr.status)
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
      console.error("Network error loading edit content")
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
    
    console.log("Sending XHR request...")
    xhr.send()
  }

  // Method to be called from turbo streams
  closeModal() {
    console.log("dialog_controller closeModal called")
    this.close()
  }

  // Simple action to close modal that can be called via turbo stream action
  closeViaAction() {
    console.log("closeViaAction called")
    this.close()
    if (window.showToast) {
      window.showToast('success', '', 'Operación exitosa')
    }
  }
}