import { Controller } from "@hotwired/stimulus"
import { Chart, registrables } from 'chart.js'

Chart.register(...registrables)

// Connects to data-controller="dashboard"
export default class extends Controller {
  initialize() {
    const data = [10 ,20 ,30 ,40 ,50 ,60 ,70, 80]
    const labels = ['Lun', 'Mar', 'Mier', 'Jue', 'Vie', 'Sab', 'Dom']
  }
}
