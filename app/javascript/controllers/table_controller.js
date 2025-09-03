import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="table"
export default class extends Controller {
  static values = { 
    sortable: { type: Boolean, default: false },
  }

  connect() {
    if (this.sortableValue) {
      this.setupSorting()
    }
  }

  setupSorting() {
    const headers = this.element.querySelectorAll('th[data-sortable]')
    headers.forEach(header => {
      header.addEventListener('click', this.sort.bind(this))
    })
  }

  sort(event) {
    const header = event.currentTarget
    const column = header.dataset.sortable
    const url = new URL(window.location.href)
    const currentDirection = url.searchParams.get("direction") || "asc"
    const newDirection = currentDirection === "asc" ? "desc" : "asc"

    url.searchParams.set("column", column)
    url.searchParams.set("direction", newDirection)
    window.location.href = url.toString()
  }
}