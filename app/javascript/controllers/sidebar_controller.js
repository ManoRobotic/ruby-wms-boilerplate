import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sidebar"
export default class extends Controller {
  static targets = ["sidebar", "toggle", "content", "link"]
  static classes = ["open", "closed"]
  
  initialize() {
    this.isOpen = false
  }

  connect() {
    this.setupInitialState()
    this.bindEvents()
  }

  setupInitialState() {
    // Check localStorage and screen size for initial state
    const savedState = localStorage.getItem("sidebarOpen")
    const isLargeScreen = window.innerWidth >= 1024
    
    this.isOpen = savedState === "true" || isLargeScreen
    this.updateSidebarState()
  }

  bindEvents() {
    // Bind resize event
    this.resizeHandler = this.handleResize.bind(this)
    window.addEventListener("resize", this.resizeHandler)
    
    // Bind scroll event for mobile
    this.scrollHandler = this.closeSidebarOnMobile.bind(this)
    window.addEventListener("scroll", this.scrollHandler)
    
    // Bind document click for outside clicks
    this.documentClickHandler = this.handleDocumentClick.bind(this)
    document.addEventListener("click", this.documentClickHandler)
  }

  disconnect() {
    window.removeEventListener("resize", this.resizeHandler)
    window.removeEventListener("scroll", this.scrollHandler)
    document.removeEventListener("click", this.documentClickHandler)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    this.isOpen = !this.isOpen
    this.updateSidebarState()
    this.saveSidebarState()
  }

  linkClicked() {
    this.closeSidebarOnMobile()
  }

  updateSidebarState() {
    const sidebar = this.sidebarTarget
    const content = this.hasContentTarget ? this.contentTarget : document.querySelector("main")
    
    if (this.isOpen) {
      sidebar.classList.remove("-translate-x-full")
      sidebar.classList.add("translate-x-0")
      if (content) {
        content.classList.add("lg:ml-64")
      }
    } else {
      sidebar.classList.add("-translate-x-full")
      sidebar.classList.remove("translate-x-0")
      if (content) {
        content.classList.remove("lg:ml-64")
      }
    }
    
    // Handle mobile overlay
    if (window.innerWidth < 1024 && this.isOpen) {
      sidebar.classList.add("z-50")
    } else {
      sidebar.classList.remove("z-50")
    }
  }

  closeSidebarOnMobile() {
    if (window.innerWidth < 1024 && this.isOpen) {
      this.isOpen = false
      this.updateSidebarState()
    }
  }

  handleResize() {
    const isLargeScreen = window.innerWidth >= 1024
    const savedState = localStorage.getItem("sidebarOpen")
    
    this.isOpen = isLargeScreen || savedState === "true"
    this.updateSidebarState()
  }

  handleDocumentClick(event) {
    const sidebar = this.sidebarTarget
    const toggle = this.toggleTarget
    
    if (window.innerWidth < 1024 && 
        this.isOpen && 
        !sidebar.contains(event.target) && 
        event.target !== toggle) {
      this.closeSidebarOnMobile()
    }
  }

  saveSidebarState() {
    localStorage.setItem("sidebarOpen", this.isOpen.toString())
  }
}