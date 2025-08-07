import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="assign-modal"
export default class extends Controller {
  static targets = ["description", "userSelect", "modal"]
  static values = { taskId: String, taskType: String }

  connect() {
    console.log("Assign modal controller connected")
    // Add document click listener to close dropdown when clicking outside
    this.handleDocumentClick = this.handleDocumentClick.bind(this)
  }

  open(event) {
    console.log("Open method called", event)
    const button = event.currentTarget
    console.log("Button:", button)
    
    this.taskIdValue = button.dataset.taskId
    this.taskTypeValue = button.dataset.taskType
    
    console.log("Opening dropdown for task:", this.taskIdValue, this.taskTypeValue)
    
    if (this.hasDescriptionTarget) {
      this.descriptionTarget.textContent = `Tarea: ${this.taskTypeValue}`
    }
    
    // Position dropdown near the button
    const buttonRect = button.getBoundingClientRect()
    const modal = this.modalTarget
    
    // Show dropdown first to get its width
    modal.classList.remove("hidden")
    
    // Position dropdown below the button, aligned with right edge
    modal.style.top = `${buttonRect.bottom + window.scrollY + 5}px`
    modal.style.left = `${buttonRect.right + window.scrollX - modal.offsetWidth}px`
    
    // Add document click listener to close when clicking outside
    document.addEventListener('click', this.handleDocumentClick)
    
    console.log("Dropdown positioned and shown")
  }

  close() {
    console.log("Closing dropdown")
    this.taskIdValue = ""
    this.taskTypeValue = ""
    if (this.hasUserSelectTarget) {
      this.userSelectTarget.value = ""
    }
    this.modalTarget.classList.add("hidden")
    
    // Remove document click listener
    document.removeEventListener('click', this.handleDocumentClick)
  }

  assign() {
    console.log("Assign method called")
    
    if (!this.hasUserSelectTarget) {
      console.error("userSelect target not found")
      return
    }
    
    const userId = this.userSelectTarget.value
    const selectElement = this.userSelectTarget
    
    console.log("UserSelect element:", selectElement)
    console.log("Available options:", Array.from(selectElement.options).map(opt => ({ value: opt.value, text: opt.text })))
    console.log("Selected value:", userId)
    console.log("Assigning task:", this.taskIdValue, "to user:", userId)
    
    if (!userId || !this.taskIdValue) {
      alert("Por favor selecciona un usuario")
      return
    }
    
    // Use fetch to submit the assignment
    const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content')
    const url = `/admin/tasks/${this.taskIdValue}/assign`
    
    console.log("Making fetch request to:", url)
    console.log("Task ID value:", this.taskIdValue)
    console.log("Full URL:", window.location.origin + url)
    console.log("With data:", { user_id: userId })
    
    const formData = new FormData()
    formData.append('user_id', userId)
    formData.append('authenticity_token', csrfToken)
    
    fetch(url, {
      method: 'PATCH',
      body: formData,
      headers: {
        'X-CSRF-Token': csrfToken,
        'Accept': 'application/json'
      }
    })
    .then(response => {
      console.log("Response received:", response)
      console.log("Response status:", response.status)
      console.log("Response URL:", response.url)
      return response.json().then(data => ({
        status: response.status,
        ok: response.ok,
        data: data
      }))
    })
    .then(({ status, ok, data }) => {
      console.log("Response data:", data)
      if (ok && data.success) {
        console.log("Assignment successful, reloading page")
        window.location.reload()
      } else {
        console.error("Assignment failed:", data.message)
        alert(data.message || "Error al asignar la tarea")
      }
    })
    .catch(error => {
      console.error("Fetch error:", error)
      alert("Error de conexión")
    })
    
    this.close()
  }

  handleDocumentClick(event) {
    // Close dropdown if click is outside the dropdown and not on an assign button
    const isClickInside = this.modalTarget.contains(event.target) || 
                         event.target.closest('[data-action*="assign-modal#open"]')
    
    if (!isClickInside) {
      this.close()
    }
  }

  clickOutside(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }
}