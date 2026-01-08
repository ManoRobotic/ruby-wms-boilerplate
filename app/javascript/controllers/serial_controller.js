import { Controller } from "@hotwired/stimulus"
import { io } from "socket.io-client"

export default class extends Controller {
  static targets = ["status", "weight", "scalePort", "printerPort", "logs", "printerStatus", "scaleStatus", "readButton"]
  static values = { 
    baseUrl: String,
    autoConnect: Boolean,
    pollInterval: Number 
  }

  connect() {
    // Get the base URL from the company configuration if available
    const companyConfig = document.querySelector('[data-serial-company-config]')
    if (companyConfig) {
      try {
        const config = JSON.parse(companyConfig.textContent)
        if (config.serial_service_url) {
          // Store the external service URL for potential later use, but use Rails API for browser requests
          this.externalBaseUrl = config.serial_service_url.replace(/\/$/, '') // Remove trailing slash
        }
      } catch (e) {
        console.error('Error parsing company config:', e)
      }
    }
    
    // Always use the Rails API for browser requests to avoid CORS issues
    this.baseUrlValue = "/api/serial"
    this.pollIntervalValue = this.pollIntervalValue || 10000 // 10s default for optimization
    this.lastActivity = Date.now()
    
    // Setup external logs panel if it exists
    this.setupExternalLogs()
    
    // Setup external clear logs button if it exists
    this.setupExternalClearLogs()

    // Add event listeners for port selection changes
    if (this.hasScalePortTarget) {
      this.scalePortTarget.addEventListener('change', (event) => this.onScalePortChange(event))
    }
    if (this.hasPrinterPortTarget) {
      this.printerPortTarget.addEventListener('change', (event) => this.onPrinterPortChange(event))
    }

    // NEW: Optimization - Pause when tab is inactive
    document.addEventListener("visibilitychange", () => {
      if (document.visibilityState === 'visible') {
        this.log("Tab visible, resuming check...")
        this.checkStatusAndAutoReconnect()
      } else {
        this.log("Tab hidden, pausing activity checks.")
        // No need to stop polling as it's removed. The WebSocket will stay connected.
      }
    })

    // NEW: Optimization - Pause on inactivity
    const resetInactivity = () => { this.lastActivity = Date.now() }
    ['mousedown', 'mousemove', 'keypress', 'scroll', 'touchstart'].forEach(name => {
      document.addEventListener(name, resetInactivity, { passive: true })
    })

    // NEW: Check server status and auto-reconnect
    this.checkStatusAndAutoReconnect()
    
    // NEW: Initialize WebSocket connection (Local-first)
    this.initWebSocket()

    // Iniciar verificación periódica del estado
    this.startHealthCheck()
    
    this.log("Serial controller initialized (Socket.IO version)")
  }

  async checkStatusAndAutoReconnect() {
    this.updateStatus("↻ Verificando estado...", "info")
    
    try {
      // 1. Cargar puertos disponibles primero
      await this.loadPorts()
      
      // 2. Cargar configuración guardada del servidor (puertos preferidos)
      await this.loadSavedConfiguration()

      // 3. Consultar estado real del servidor serial
      const response = await fetch(`${this.baseUrlValue}/status`, {
        headers: { 'ngrok-skip-browser-warning': '1' }
      })
      const data = await response.json()
      
      if (data.status === 'healthy' || data.status === 'success') {
        const wasManuallyDisconnected = localStorage.getItem('serial_manual_disconnect') === 'true'
        
        // Manejar Báscula
        if (data.scale_connected) {
          this.updateScaleStatus("Conectada", "success")
          if (this.hasScalePortTarget && data.scale_port) {
            this.scalePortTarget.value = data.scale_port
          }
          this.startReading()
          this.log(`Báscula ya estaba conectada en ${data.scale_port}`)
        } else if (this.autoConnectValue && !wasManuallyDisconnected && this.hasScalePortTarget && this.scalePortTarget.value) {
          this.log("Intentando auto-conexión de báscula...")
          this.connectScale({ preventDefault: () => {} })
        }

        // Manejar Impresora
        if (data.printer_connected) {
          this.updatePrinterStatus("Conectada", "success")
          if (this.hasPrinterPortTarget && data.printer_port) {
            this.printerPortTarget.value = data.printer_port
          }
          this.log(`Impresora ya estaba conectada en ${data.printer_port}`)
        } else if (this.autoConnectValue && !wasManuallyDisconnected && this.hasPrinterPortTarget && this.printerPortTarget.value) {
          this.log("Intentando auto-conexión de impresora...")
          this.connectPrinter({ preventDefault: () => {} })
        }

        this.updateStatus("✓ Sistema listo", "success")
      } else {
        this.updateStatus("✗ Servidor serial no disponible", "error")
      }
    } catch (error) {
      this.updateStatus("✗ Error al verificar estado", "error")
      this.log(`Status check error: ${error.message}`)
    }
  }

  // Método para cargar la configuración guardada
  async loadSavedConfiguration() {
    try {
      const response = await fetch('/admin/configurations/saved_config', {
        headers: { 
          'ngrok-skip-browser-warning': '1',
          'Accept': 'application/json'
        }
      })
      const data = await response.json()
      
      if (data.serial_port && this.hasScalePortTarget) {
        this.scalePortTarget.value = data.serial_port
      }
      
      if (data.printer_port && this.hasPrinterPortTarget) {
        this.printerPortTarget.value = data.printer_port
      }
      return data
    } catch (error) {
      this.log(`Error loading saved configuration: ${error.message}`)
      return {}
    }
  }

  disconnect() {
    this.stopHealthCheck()
    if (this.socket) {
      this.socket.disconnect()
    }
  }

  startHealthCheck() {
    // Verificar el estado cada 5 minutos para ahorrar peticiones
    this.healthCheckInterval = setInterval(() => {
      if (document.visibilityState === 'visible') {
        this.checkHealth()
      }
    }, 300000)
  }

  stopHealthCheck() {
    if (this.healthCheckInterval) {
      clearInterval(this.healthCheckInterval)
      this.healthCheckInterval = null
    }
  }

  // NEW: WebSocket Initialization using Socket.IO
  initWebSocket() {
    if (!this.externalBaseUrl) return

    this.log("Intentando conexión compatible con Socket.IO...")
    
    // Construct the Socket.IO URL (base URL without /weight namespace, namespace handled by client)
    // externalBaseUrl is like "https://...ngrok-free.app", io() needs "https://...ngrok-free.app"
    const serverUrl = this.externalBaseUrl;

    try {
      if (typeof io === 'undefined') {
        this.log("Error: Librería socket.io-client no cargada.")
        return
      }

      // Connect to the /weight namespace
      this.socket = io(`${serverUrl}/weight`, {
        transports: ['websocket', 'polling'],
        reconnection: true,
        reconnectionAttempts: 5,
        reconnectionDelay: 1000
      })

      this.socket.on('connect', () => {
        this.log("Socket.IO conectado (/weight)")
        this.isWsConnected = true
        this.updateStatus("✓ Conectado en tiempo real", "success")
      })

      this.socket.on('weight_update', (data) => {
        // data matches { weight: ..., timestamp: ... } from server
        if (data.weight !== undefined) {
          this.updateWeight(data.weight, data.timestamp || new Date().toISOString())
        }
      })

      this.socket.on('connect_error', (error) => {
        console.error("Socket.IO connection error:", error)
        // Check if we are already disconnected to avoid spam
        if (this.isWsConnected) {
          this.log(`Socket.IO error: ${error.message}`)
          this.isWsConnected = false
        }
      })

      this.socket.on('disconnect', (reason) => {
        this.log(`Socket.IO desconectado: ${reason}`)
        this.isWsConnected = false
        this.updateStatus("↻ Intentando reconectar...", "warning")
        
        if (reason === "io server disconnect") {
          // The disconnection was initiated by the server, you need to reconnect manually
          this.socket.connect();
        }
        // Do NOT fallback to polling here. Let the socket.io client handle reconnection.
      })

    } catch (e) {
      this.log(`Error iniciando Socket.IO: ${e.message}`)
      console.error(e)
    }
  }

  // Legacy method removed
  attemptWebSocket(url, isLocal) {}

  async checkHealth() {
    // Mostrar estado de verificación en progreso
    this.updateStatus("↻ Verificando conexión...", "info")
    
    try {
      const response = await fetch(`${this.baseUrlValue}/health`, {
        headers: { 'ngrok-skip-browser-warning': '1' }
      })
      const data = await response.json()
      
      if (data.status === 'healthy') {
        this.updateStatus("✓ Serial server connected", "success")
        await this.loadPorts()
      } else {
        this.updateStatus("✗ Serial server unavailable", "error")
      }
    } catch (error) {
      this.updateStatus("✗ Cannot reach serial server", "error")
      this.log(`Health check error: ${error.message}`)
    }
  }

  async loadPorts() {
    try {
      const response = await fetch(`${this.baseUrlValue}/ports`, {
        headers: { 'ngrok-skip-browser-warning': '1' }
      })
      const data = await response.json()
      
      if (data.status === 'success') {
        // Cargar puertos en el dropdown de la báscula si existe
        if (this.hasScalePortTarget) {
          // Guardar el puerto actualmente seleccionado
          const currentScaleSelection = this.scalePortTarget.value;
          
          // Limpiar opciones actuales
          this.scalePortTarget.innerHTML = '<option value="">Detectando puertos...</option>'
          
          // Agregar puertos disponibles
          if (data.ports && data.ports.length > 0) {
            this.scalePortTarget.innerHTML = '<option value="">Seleccionar puerto...</option>'
            data.ports.forEach(port => {
              const option = document.createElement('option')
              option.value = port.device
              option.textContent = `${port.device} - ${port.description || 'Dispositivo serial'}`            
              this.scalePortTarget.appendChild(option)
            })
            
            // Restaurar selección anterior si existe
            if (currentScaleSelection) {
              this.scalePortTarget.value = currentScaleSelection
            }
          } else {
            this.scalePortTarget.innerHTML = '<option value="">No se encontraron puertos</option>'
          }
        }
        
        // Cargar puertos en el dropdown de la impresora si existe
        if (this.hasPrinterPortTarget) {
          // Guardar el puerto actualmente seleccionado
          const currentPrinterSelection = this.printerPortTarget.value;
          
          // Limpiar opciones actuales
          this.printerPortTarget.innerHTML = '<option value="">Detectando puertos...</option>'
          
          // Agregar puertos disponibles
          if (data.ports && data.ports.length > 0) {
            this.printerPortTarget.innerHTML = '<option value="">Seleccionar puerto...</option>'
            data.ports.forEach(port => {
              const option = document.createElement('option')
              option.value = port.device
              option.textContent = `${port.device} - ${port.description || 'Dispositivo serial'}`            
              this.printerPortTarget.appendChild(option)
            })
            
            // Restaurar selección anterior si existe
            if (currentPrinterSelection) {
              this.printerPortTarget.value = currentPrinterSelection
            }
          } else {
            this.printerPortTarget.innerHTML = '<option value="">No se encontraron puertos</option>'
          }
        }
        
        
      } else {
        // Handle case where API returns non-success status
        if (this.hasScalePortTarget) {
          this.scalePortTarget.innerHTML = '<option value="">No se encontraron puertos</option>'
        }
        if (this.hasPrinterPortTarget) {
          this.printerPortTarget.innerHTML = '<option value="">No se encontraron puertos</option>'
        }
      }
    } catch (error) {
      this.log(`Error loading ports: ${error.message}`)
      if (this.hasScalePortTarget) {
        this.scalePortTarget.innerHTML = '<option value="">Error al detectar puertos</option>'
      }
      if (this.hasPrinterPortTarget) {
        this.printerPortTarget.innerHTML = '<option value="">Error al detectar puertos</option>'
      }
    }
  }

  async refreshPorts(event) {
    if (event) event.preventDefault();
    
    // Mostrar mensaje de carga en ambos dropdowns
    if (this.hasScalePortTarget) {
      this.scalePortTarget.innerHTML = '<option value="">Detectando puertos...</option>';
    }
    
    if (this.hasPrinterPortTarget) {
      this.printerPortTarget.innerHTML = '<option value="">Detectando puertos...</option>';
    }
    
    // Cargar puertos
    await this.loadPorts();
    
    this.log("Puertos refrescados");
  }

  async connectScale(event) {
    event.preventDefault()
    
    const port = this.hasScalePortTarget ? this.scalePortTarget.value : '/dev/ttyS0'
    const baudrate = 115200
    
    if (!port) {
      this.updateStatus("Please select a port", "error")
      return
    }

    try {
      const response = await fetch(`${this.baseUrlValue}/connect_scale`, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': '1'
        },
        body: JSON.stringify({ port, baudrate })
      })
      
      const data = await response.json()
      
      if (data.status === 'success') {
        this.updateStatus("✓ Scale connected", "success")
        this.updateScaleStatus("Conectada", "success")
        this.log(`Scale connected on ${port}`)
        
        // Trigger Rails form submission for automatic saving
        const form = document.getElementById('serial-config-form');
        if (form) {
          this._submitAutoSaveForm({ serial_port: port, serial_baud_rate: baudrate }, form);
        }
        
        await this.startReading()
      } else {
        this.updateStatus("✗ Failed to connect scale", "error")
        this.updateScaleStatus("Error", "error")
        this.log(`Connection failed: ${data.message}`)
      }
    } catch (error) {
      this.updateStatus("✗ Connection error", "error")
      this.log(`Error: ${error.message}`)
    }
  }

  async disconnectScale(event) {
    event.preventDefault()
    
    try {
      const response = await fetch(`${this.baseUrlValue}/disconnect_scale`, {
        method: 'POST',
        headers: { 'ngrok-skip-browser-warning': '1' }
      })
      
      const data = await response.json()
        if (data.status === "success") {
        this.updateStatus("Scale disconnected", "info");
        this.updateScaleStatus("Desconectada", "info");
        this.updateWeight("--", "--");
        this.log("Scale disconnected");
      }
    } catch (error) {
      this.log(`Error disconnecting: ${error.message}`)
    }
  }

  async startReading() {
    // This function now only tells the server to start the hardware reading loop.
    // WebSocket events will handle the data updates.
    try {
      const response = await fetch(`${this.baseUrlValue}/start_scale`, {
        method: 'POST',
        headers: { 'ngrok-skip-browser-warning': '1' }
      })
      
      const data = await response.json()
      
      if (data.status === 'success') {
        this.log("Started continuous reading on server.")
      }
    } catch (error) {
      this.log(`Error starting reading: ${error.message}`)
    }
  }

  async stopReading() {
    try {
      // We no longer need to stop polling, just tell the server to stop reading.
      const response = await fetch(`${this.baseUrlValue}/stop_scale`, {
        method: 'POST',
        headers: { 'ngrok-skip-browser-warning': '1' }
      })
      
      const data = await response.json()
      this.log("Stopped continuous reading on server.")
    } catch (error) {
      this.log(`Error stopping reading: ${error.message}`)
    }
  }


  async readWeightNow(event) {
    event.preventDefault()
    
    // Mostrar spinner en el botón
    if (this.hasReadButtonTarget) {
      this.readButtonTarget.innerHTML = `
        <div class="flex items-center">
          <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-gray-700" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          Leyendo...
        </div>
      `;
      this.readButtonTarget.disabled = true;
    }
    
    try {
      const response = await fetch(`${this.baseUrlValue}/get_weight_now?timeout=5`, {
        headers: { 'ngrok-skip-browser-warning': '1' }
      })
      const data = await response.json()
      
      if (data.status === 'success') {
        this.updateWeight(data.weight, data.timestamp)
        this.log(`Weight read: ${data.weight}`)
        
        // Disparar evento personalizado con el peso
        this.dispatch('weightRead', { 
          detail: { weight: data.weight, timestamp: data.timestamp } 
        })
      } else {
        this.log("No weight reading available")
        // Mostrar mensaje de error en el display de peso
        this.updateWeight("Error", "--")
      }
    } catch (error) {
      this.log(`Error reading weight: ${error.message}`)
      // Mostrar mensaje de error en el display de peso
      this.updateWeight("Error", "--")
    } finally {
      // Restaurar el botón
      if (this.hasReadButtonTarget) {
        this.readButtonTarget.innerHTML = "Leer ahora";
        this.readButtonTarget.disabled = false;
      }
    }
  }

  async connectPrinter(event) {
    event.preventDefault()
    
    // Get the selected printer port if available
    const printerPort = this.hasPrinterPortTarget ? this.printerPortTarget.value : null
    
    try {
      const requestBody = {}
      if (printerPort) {
        requestBody.port = printerPort
      }
      
      const response = await fetch(`${this.baseUrlValue}/connect_printer`, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': '1'
        },
        body: JSON.stringify(requestBody)
      })
      
      const data = await response.json()
      
      if (data.status === 'success') {
        this.updatePrinterStatus("Conectada", "success")
        this.log(`Printer connected on ${printerPort || 'auto-detected port'}`)
        
        // Trigger Rails form submission for automatic saving if we have a specific port
        const form = document.getElementById('serial-config-form');
        const baudrate = 115200; // Default baud rate for printer
        if (form && printerPort) {
          this._submitAutoSaveForm({ printer_port: printerPort, printer_baud_rate: baudrate }, form);
        }
      } else {
        this.updatePrinterStatus("Error", "error")
        this.log(`Printer connection failed: ${data.message}`)
      }
    } catch (error) {
      this.updatePrinterStatus("✗ Connection error", "error")
      this.log(`Error: ${error.message}`)
    }
  }

  async printLabel(event) {
    event.preventDefault()
    
    const content = event.target.dataset.content || "Test Label"
    const ancho_mm = event.target.dataset.ancho || 80
    const alto_mm = event.target.dataset.alto || 50
    
    try {
      const response = await fetch(`${this.baseUrlValue}/print_label`, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': '1'
        },
        body: JSON.stringify({ 
          content, 
          ancho_mm: parseInt(ancho_mm), 
          alto_mm: parseInt(alto_mm) 
        })
      })
      
      const data = await response.json()
      
      if (data.status === 'success') {
        this.log(`Label printed: ${content} (${ancho_mm}x${alto_mm}mm)`)
        
        // Disparar evento personalizado
        this.dispatch('labelPrinted', { 
          detail: { content, ancho_mm, alto_mm } 
        })
      } else {
        this.log(`Print failed: ${data.message}`)
      }
    } catch (error) {
      this.log(`Print error: ${error.message}`)
    }
  }

  async testPrinter(event) {
    event.preventDefault()
    
    const ancho_mm = event.target.dataset.ancho || 80
    const alto_mm = event.target.dataset.alto || 50
    
    try {
      const response = await fetch(`${this.baseUrlValue}/test_printer`, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': '1'
        },
        body: JSON.stringify({ 
          ancho_mm: parseInt(ancho_mm), 
          alto_mm: parseInt(alto_mm) 
        })
      })
      
      const data = await response.json()
      
      if (data.status === 'success') {
        this.log(`Printer test executed (${ancho_mm}x${alto_mm}mm)`)
        // Trigger Rails form submission for automatic saving
        const form = document.getElementById('serial-config-form');
        if (form) {
          // Assuming default baud rate for test, or retrieve from another source if available
          this._submitAutoSaveForm({ 
            printer_port: this.hasPrinterPortTarget ? this.printerPortTarget.value : 'auto_detected',
            printer_baud_rate: 9600 
          }, form);
        }
      } else {
        this.log(`Test failed: ${data.message}`)
      }
    } catch (error) {
      this.log(`Test error: ${error.message}`)
    }
  }

  // Método para imprimir desde otros controllers
  async printCustomLabel(content, ancho_mm = 80, alto_mm = 50) {
    try {
      const response = await fetch(`${this.baseUrlValue}/print_label`, {
        method: 'POST',
        headers: { 
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': '1'
        },
        body: JSON.stringify({ 
          content, 
          ancho_mm: parseInt(ancho_mm), 
          alto_mm: parseInt(alto_mm) 
        })
      })
      
      const data = await response.json()
      
      if (data.status === 'success') {
        this.log(`Custom label printed: ${content} (${ancho_mm}x${alto_mm}mm)`)
      } else {
        this.log(`Print failed: ${data.message}`)
      }
      
      return data.status === 'success'
    } catch (error) {
      this.log(`Print error: ${error.message}`)
      return false
    }
  }

  // Método para obtener peso desde otros controllers
  async getCurrentWeight(timeout = 5) {
    try {
      const response = await fetch(`${this.baseUrlValue}/get_weight_now?timeout=${timeout}`, {
        headers: { 'ngrok-skip-browser-warning': '1' }
      })
      const data = await response.json()
      
      if (data.status === 'success') {
        return { weight: data.weight, timestamp: data.timestamp }
      }
      return null
    } catch (error) {
      return null
    }
  }

  updateStatus(message, type = "info") {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      // Use Tailwind classes instead of custom CSS
      switch(type) {
        case "success":
          this.statusTarget.className = "px-2 py-1 rounded text-sm font-medium bg-green-100 text-green-800"
          break
        case "error":
          this.statusTarget.className = "px-2 py-1 rounded text-sm font-medium bg-red-100 text-red-800"
          break
        case "warning":
          this.statusTarget.className = "px-2 py-1 rounded text-sm font-medium bg-yellow-100 text-yellow-800"
          break
        case "info":
        default:
          this.statusTarget.className = "px-2 py-1 rounded text-sm font-medium bg-blue-100 text-blue-800"
          break
      }
    }
  }

  updateWeight(weight, timestamp) {
    if (this.hasWeightTarget) {
      // Agregar animación de loading mientras se actualiza
      this.weightTarget.innerHTML = `
        <div class="text-2xl font-bold text-center text-blue-500">Leyendo...</div>
        <div class="text-sm text-center text-gray-500">--</div>
      `
      
      // Después de un breve delay, mostrar el peso con animación
      setTimeout(() => {
        this.weightTarget.innerHTML = `
          <div class="text-2xl font-bold text-center text-gray-400">${weight}</div>
          <div class="text-sm text-center text-gray-500">${timestamp}</div>
        `
        
        // Trigger weight animation by removing and adding class
        const weightDisplay = this.weightTarget.querySelector('.text-2xl')
        if (weightDisplay && weight !== '--') {
          weightDisplay.classList.remove('text-gray-400')
          weightDisplay.classList.add('text-emerald-600')
        }
      }, 300)
    }
  }

  updateScaleStatus(message, type = "info") {
    if (this.hasScaleStatusTarget) {
      this.scaleStatusTarget.textContent = message
      // Use Tailwind classes instead of custom CSS
      switch(type) {
        case "success":
          this.scaleStatusTarget.className = "px-2 py-1 rounded text-sm font-medium bg-green-100 text-green-800"
          break
        case "error":
          this.scaleStatusTarget.className = "px-2 py-1 rounded text-sm font-medium bg-red-100 text-red-800"
          break
        case "info":
        default:
          this.scaleStatusTarget.className = "px-2 py-1 rounded text-sm font-medium bg-gray-100 text-gray-800"
          break
      }
    }
  }

  updatePrinterStatus(message, type = "info") {
    if (this.hasPrinterStatusTarget) {
      this.printerStatusTarget.textContent = message
      // Use Tailwind classes instead of custom CSS
      switch(type) {
        case "success":
          this.printerStatusTarget.className = "px-2 py-1 rounded text-sm font-medium bg-green-100 text-green-800"
          break
        case "error":
          this.printerStatusTarget.className = "px-2 py-1 rounded text-sm font-medium bg-red-100 text-red-800"
          break
        case "info":
        default:
          this.printerStatusTarget.className = "px-2 py-1 rounded text-sm font-medium bg-gray-100 text-gray-800"
          break
      }
    }
  }

  log(message) {
    const timestamp = new Date().toLocaleTimeString()
    const logMessage = `[${timestamp}] ${message}`
    
    console.log(logMessage)
    
    if (this.hasLogsTarget) {
      const logLine = document.createElement('div')
      logLine.textContent = logMessage
      logLine.className = 'log-line'
      
      this.logsTarget.appendChild(logLine)
      this.logsTarget.scrollTop = this.logsTarget.scrollHeight
      
      // Mantener solo las últimas 50 líneas
      while (this.logsTarget.children.length > 50) {
        this.logsTarget.removeChild(this.logsTarget.firstChild)
      }
    }
    
    // Also add to external logs panel
    this.appendToExternalLogs(logMessage)
  }

  setupExternalLogs() {
    this.externalLogsElement = document.getElementById('external-serial-logs');
  }
  
  setupExternalClearLogs() {
    const externalClearLogsButton = document.getElementById('external-clear-logs');
    if (externalClearLogsButton) {
      externalClearLogsButton.addEventListener('click', () => {
        this.clearExternalLogs();
      });
    }
  }
  
  clearLogs() {
    if (this.hasLogsTarget) {
      this.logsTarget.innerHTML = ''
    }
    this.clearExternalLogs();
  }
  
  clearExternalLogs() {
    if (this.externalLogsElement) {
      this.externalLogsElement.innerHTML = '';
    }
  }
  
  appendToExternalLogs(message) {
    if (this.externalLogsElement) {
      const logLine = document.createElement('div');
      logLine.textContent = message;
      logLine.className = 'log-line';
      
      this.externalLogsElement.appendChild(logLine);
      this.externalLogsElement.scrollTop = this.externalLogsElement.scrollHeight;
      
      // Mantener solo las últimas 50 líneas
      while (this.externalLogsElement.children.length > 50) {
        this.externalLogsElement.removeChild(this.externalLogsElement.firstChild);
      }
    }
  }

  // Método para manejar cambios en la selección de puerto de la báscula
  onScalePortChange(event) {
    const selectedPort = event.target.value
    const form = document.getElementById('serial-config-form');
    if (selectedPort && form) {
      this._submitAutoSaveForm({ serial_port: selectedPort }, form);
      this.log(`Puerto de báscula seleccionado: ${selectedPort}`)
    }
  }

  // Método para manejar cambios en la selección de puerto de la impresora
  onPrinterPortChange(event) {
    const selectedPort = event.target.value
    const form = document.getElementById('serial-config-form');
    if (selectedPort && form) {
      this._submitAutoSaveForm({ printer_port: selectedPort }, form);
      this.log(`Puerto de impresora seleccionado: ${selectedPort}`)
    }
  }

  // Internal method to update hidden fields and submit the form
  _submitAutoSaveForm(configData, form) {
    Object.keys(configData).forEach(key => {
      // Find the hidden input field based on its ID
      // This assumes hidden fields are named like auto-save-serial-port
      const field = form.querySelector(`#auto-save-${key.replace(/_/g, '-')}`);
      if (field) {
        field.value = configData[key];
      } else {
        this.log(`Warning: Hidden field for ${key} not found in auto-save form.`);
      }
    });

    const formData = new FormData(form);
    // Force .json extension to ensure Rails returns JSON
    const actionUrl = form.action.endsWith('.json') ? form.action : `${form.action}.json`;

    fetch(actionUrl, {
      method: 'POST',
      body: formData,
      headers: {
        'X-Requested-With': 'XMLHttpRequest',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'ngrok-skip-browser-warning': '1',
        'Accept': 'application/json'
      }
    })
    .then(async response => {
      const contentType = response.headers.get("content-type");
      const text = await response.text();
      
      if (!response.ok) {
        throw new Error(`Server returned ${response.status} ${response.statusText}: ${text.substring(0, 200)}...`);
      }
      
      // Try to parse JSON regardless of content-type, but warn if mismatch
      try {
        return JSON.parse(text);
      } catch (e) {
        throw new Error(`Invalid JSON response (CT: ${contentType}): ${text.substring(0, 200)}...`);
      }
    })
    .then(data => {
      if (data.success) {
        this.log(`Configuración guardada automáticamente: ${JSON.stringify(configData)}`);
        this.updateStatus('✓ Configuración guardada automáticamente', 'success');
      } else {
        this.log(`Error al guardar configuración automáticamente: ${data.message}`);
        this.updateStatus('✗ Error al guardar configuración automáticamente', 'error');
      }
    })
    .catch(error => {
      console.error("Auto-save error full details:", error);
      // Clean up error message for UI
      let uiMessage = error.message;
      if (uiMessage.includes("Invalid JSON")) {
        uiMessage = "Error de respuesta del servidor (Formato inválido)";
      }
      this.log(`Error de red al guardar configuración automáticamente: ${error.message}`);
      this.updateStatus(`✗ Error: ${uiMessage.substring(0, 40)}...`, 'error');
    });
  }

  async saveConfiguration(event) {
    event.preventDefault();

    const form = event.target.closest('form');
    if (!form) {
      this.log('Error: Auto-save form not found for manual submission.');
      this.updateStatus('✗ Error al guardar configuración: formulario no encontrado', 'error');
      return;
    }

    const configData = {};
    
    // Collect all hidden fields starting with 'auto-save-' and populate configData
    form.querySelectorAll('input[type="hidden"][id^="auto-save-"]').forEach(field => {
      // Convert id like 'auto-save-serial-port' to 'serial_port'
      const key = field.id.replace('auto-save-', '').replace(/-/g, '_');
      configData[key] = field.value;
    });

    // Ensure essential parameters like baud rates are set, using defaults if not already present
    if (!configData.serial_baud_rate) {
      configData.serial_baud_rate = 115200; 
    }
    if (!configData.printer_baud_rate) {
      configData.printer_baud_rate = 115200;
    }
    
    this._submitAutoSaveForm(configData, form);
  }
}