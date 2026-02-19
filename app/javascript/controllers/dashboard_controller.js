import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from 'chart.js'
Chart.register(...registerables)

// Connects to data-controller="dashboard"
export default class extends Controller {
  static values = { 
    production: Array,
    weight: Array
  }

  connect() {
    this.renderProductionChart()
    this.renderWeightChart()
  }

  renderProductionChart() {
    const ctx = document.getElementById('productionChart')
    if (!ctx) return

    const labels = this.productionValue.map(item => item[0])
    const data = this.productionValue.map(item => item[1])

    this.createChart(ctx, 'Cortes/Folios', data, labels, '#4f46e5', 'rgba(79, 70, 229, 0.1)')
  }

  renderWeightChart() {
    const ctx = document.getElementById('weightChart')
    if (!ctx) return

    const labels = this.weightValue.map(item => item[0])
    const data = this.weightValue.map(item => item[1])

    this.createChart(ctx, 'Peso Neto (kg)', data, labels, '#10b981', 'rgba(16, 185, 129, 0.1)')
  }

  createChart(ctx, label, data, labels, color, bgColor) {
    const gradient = ctx.getContext('2d').createLinearGradient(0, 0, 0, 400)
    gradient.addColorStop(0, bgColor)
    gradient.addColorStop(1, 'rgba(255, 255, 255, 0)')

    new Chart(ctx, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [{
          label: label,
          data: data,
          borderColor: color,
          backgroundColor: gradient,
          borderWidth: 3,
          pointBackgroundColor: color,
          pointBorderColor: '#fff',
          pointBorderWidth: 2,
          pointRadius: 4,
          pointHoverRadius: 6,
          fill: true,
          tension: 0.4 // Bezier curve tension
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          intersect: false,
          mode: 'index',
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            backgroundColor: '#1e293b',
            padding: 12,
            titleFont: { size: 14, weight: 'bold' },
            bodyFont: { size: 13 },
            cornerRadius: 8,
            displayColors: false
          }
        },
        scales: {
          x: {
            grid: {
              display: false
            },
            ticks: {
              font: { size: 11 },
              color: '#94a3b8'
            }
          },
          y: {
            beginAtZero: true,
            border: {
              dash: [4, 4],
              display: false
            },
            grid: {
              color: '#f1f5f9'
            },
            ticks: {
              font: { size: 11 },
              color: '#94a3b8',
              maxTicksLimit: 5
            }
          }
        }
      }
    })
  }
}