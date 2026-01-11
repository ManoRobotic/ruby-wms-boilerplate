class SerialCommunicationService
  # Use ActionCable for communication instead of HTTP requests
  class << self
    def health_check(company: nil)
      # Check if the company has a valid device ID and token
      company&.serial_device_id.present? && company&.serial_auth_token.present?
    rescue StandardError => e
      Rails.logger.error "Serial server health check failed: #{e.message}"
      false
    end

    def list_serial_ports(company: nil)
      # This will be populated by the ActionCable connection
      # For now, return an empty array - the actual data comes from the client
      []
    rescue StandardError => e
      Rails.logger.error "Failed to list serial ports: #{e.message}"
      []
    end

    def connect_scale(port: 'COM3', baudrate: 115200, company: nil)
      # This is now handled by sending a message through ActionCable
      # The actual connection happens on the client side
      broadcast_to_company(company, {
        action: 'connect_scale',
        port: port,
        baudrate: baudrate
      })
      true
    rescue StandardError => e
      Rails.logger.error "Failed to connect scale: #{e.message}"
      false
    end

    def disconnect_scale(company: nil)
      broadcast_to_company(company, {
        action: 'disconnect_scale'
      })
      true
    rescue StandardError => e
      Rails.logger.error "Failed to disconnect scale: #{e.message}"
      false
    end

    def start_scale_reading(company: nil)
      broadcast_to_company(company, {
        action: 'start_scale_reading'
      })
      true
    rescue StandardError => e
      Rails.logger.error "Failed to start scale reading: #{e.message}"
      false
    end

    def stop_scale_reading(company: nil)
      broadcast_to_company(company, {
        action: 'stop_scale_reading'
      })
      true
    rescue StandardError => e
      Rails.logger.error "Failed to stop scale reading: #{e.message}"
      false
    end

    def read_scale_weight(company: nil)
      # This will be populated by the ActionCable connection
      # For now, return nil - the actual data comes from the client
      nil
    rescue StandardError => e
      Rails.logger.error "Failed to read scale weight: #{e.message}"
      nil
    end

    def get_last_reading(company: nil)
      # This will be populated by the ActionCable connection
      # For now, return nil - the actual data comes from the client
      nil
    rescue StandardError => e
      Rails.logger.error "Failed to get last reading: #{e.message}"
      nil
    end

    def get_latest_readings(company: nil)
      # This will be populated by the ActionCable connection
      # For now, return an empty array - the actual data comes from the client
      []
    rescue StandardError => e
      Rails.logger.error "Failed to get latest readings: #{e.message}"
      []
    end

    def connect_printer(company: nil)
      broadcast_to_company(company, {
        action: 'connect_printer'
      })
      true
    rescue StandardError => e
      Rails.logger.error "Failed to connect printer: #{e.message}"
      false
    end

    def print_label(content, ancho_mm: 80, alto_mm: 50, company: nil)
      broadcast_to_company(company, {
        action: 'print_label',
        content: content,
        ancho_mm: ancho_mm,
        alto_mm: alto_mm
      })
      true
    rescue StandardError => e
      Rails.logger.error "Failed to print label: #{e.message}"
      false
    end

    def test_printer(ancho_mm: 80, alto_mm: 50, company: nil)
      broadcast_to_company(company, {
        action: 'test_printer',
        ancho_mm: ancho_mm,
        alto_mm: alto_mm
      })
      true
    rescue StandardError => e
      Rails.logger.error "Failed to test printer: #{e.message}"
      false
    end

    def disconnect_printer(company: nil)
      broadcast_to_company(company, {
        action: 'disconnect_printer'
      })
      true
    rescue StandardError => e
      Rails.logger.error "Failed to disconnect printer: #{e.message}"
      false
    end

    # Obtiene el estado actual de todas las conexiones en el servidor serial
    def status(company: nil)
      # This will be populated by the ActionCable connection
      # For now, return a default status - the actual data comes from the client
      {
        status: 'connected', # Assuming connected if we have a valid company
        scale_connected: false,
        printer_connected: false,
        scale_port: company&.serial_port,
        printer_port: company&.printer_port
      }
    rescue StandardError => e
      Rails.logger.error "Serial server status check failed: #{e.message}"
      { status: 'error', message: e.message, scale_connected: false, printer_connected: false }
    end

    # Método para obtener peso en tiempo real con polling
    def get_weight_with_timeout(timeout_seconds: 10, company: nil)
      # This will be populated by the ActionCable connection
      # For now, return nil - the actual data comes from the client
      nil
    rescue StandardError => e
      Rails.logger.error "Failed to get weight with timeout: #{e.message}"
      nil
    end

    private

    def broadcast_to_company(company, data)
      return false unless company&.serial_device_id

      # Send the message through ActionCable to the specific device
      ActionCable.server.broadcast("serial_channel_#{company.serial_device_id}", data.deep_symbolize_keys)
      true
    rescue StandardError => e
      Rails.logger.error "Failed to broadcast to company #{company&.id}: #{e.message}"
      false
    end
  end
end