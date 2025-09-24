class SerialCommunicationService
  # Use dynamic URL from company configuration
  # BASE_URL = 'http://192.168.1.91:5000'  # This is now configured per company
  
  class << self
    def health_check(company: nil)
      response = get('/health', company: company)
      response['status'] == 'healthy'
    rescue StandardError => e
      Rails.logger.error "Serial server health check failed: #{e.message}"
      false
    end

    def list_serial_ports(company: nil)
      response = get('/ports', company: company)
      Rails.logger.info "Serial ports response: #{response}"
      response['ports'] || []
    rescue StandardError => e
      Rails.logger.error "Failed to list serial ports: #{e.message}"
      []
    end

    def connect_scale(port: 'COM3', baudrate: 115200, company: nil)
      payload = { port: port, baudrate: baudrate }
      response = post('/scale/connect', payload: payload, company: company)
      response['status'] == 'success'
    rescue StandardError => e
      Rails.logger.error "Failed to connect scale: #{e.message}"
      false
    end

    def disconnect_scale(company: nil)
      response = post('/scale/disconnect', payload: {}, company: company)
      response['status'] == 'success'
    rescue StandardError => e
      Rails.logger.error "Failed to disconnect scale: #{e.message}"
      false
    end

    def start_scale_reading(company: nil)
      response = post('/scale/start', payload: {}, company: company)
      response['status'] == 'success'
    rescue StandardError => e
      Rails.logger.error "Failed to start scale reading: #{e.message}"
      false
    end

    def stop_scale_reading(company: nil)
      response = post('/scale/stop', payload: {}, company: company)
      response['status'] == 'success'
    rescue StandardError => e
      Rails.logger.error "Failed to stop scale reading: #{e.message}"
      false
    end

    def read_scale_weight(company: nil)
      response = get('/scale/read', company: company)
      if response['status'] == 'success'
        {
          weight: response['weight'],
          timestamp: response['timestamp']
        }
      else
        nil
      end
    rescue StandardError => e
      Rails.logger.error "Failed to read scale weight: #{e.message}"
      nil
    end

    def get_last_reading(company: nil)
      response = get('/scale/last', company: company)
      if response['status'] == 'success'
        {
          weight: response['weight'],
          timestamp: response['timestamp']
        }
      else
        nil
      end
    rescue StandardError => e
      Rails.logger.error "Failed to get last reading: #{e.message}"
      nil
    end

    def get_latest_readings(company: nil)
      response = get('/scale/latest', company: company)
      response['readings'] || []
    rescue StandardError => e
      Rails.logger.error "Failed to get latest readings: #{e.message}"
      []
    end

    def connect_printer(company: nil)
      response = post('/printer/connect', payload: {}, company: company)
      response['status'] == 'success'
    rescue StandardError => e
      Rails.logger.error "Failed to connect printer: #{e.message}"
      false
    end

    def print_label(content, ancho_mm: 80, alto_mm: 50, company: nil)
      payload = { 
        content: content, 
        ancho_mm: ancho_mm, 
        alto_mm: alto_mm 
      }
      response = post('/printer/print', payload: payload, company: company)
      response['status'] == 'success'
    rescue StandardError => e
      Rails.logger.error "Failed to print label: #{e.message}"
      false
    end

    def test_printer(ancho_mm: 80, alto_mm: 50, company: nil)
      payload = { ancho_mm: ancho_mm, alto_mm: alto_mm }
      response = post('/printer/test', payload: payload, company: company)
      response['status'] == 'success'
    rescue StandardError => e
      Rails.logger.error "Failed to test printer: #{e.message}"
      false
    end

    def disconnect_printer(company: nil)
      response = post('/printer/disconnect', payload: {}, company: company)
      response['status'] == 'success'
    rescue StandardError => e
      Rails.logger.error "Failed to disconnect printer: #{e.message}"
      false
    end

    # Método para obtener peso en tiempo real con polling
    def get_weight_with_timeout(timeout_seconds: 10, company: nil)
      start_time = Time.current
      
      while Time.current - start_time < timeout_seconds
        reading = get_latest_readings(company: company).last
        return reading if reading && reading['weight'].present?
        
        sleep(0.5)
      end
      
      nil
    end

    private

    def get(endpoint, company: nil)
      base_url = get_base_url(company: company)
      uri = URI("#{base_url}#{endpoint}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.read_timeout = 10
      
      request = Net::HTTP::Get.new(uri)
      request['Content-Type'] = 'application/json'
      
      response = http.request(request)
      parse_response(response)
    end

    def post(endpoint, payload: {}, company: nil)
      base_url = get_base_url(company: company)
      uri = URI("#{base_url}#{endpoint}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == 'https')
      http.read_timeout = 10
      
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = payload.to_json unless payload.empty?
      
      response = http.request(request)
      parse_response(response)
    end

    def get_base_url(company: nil)
      # Use provided company, or find by name if string is provided, or get first company as fallback
      company = case company
                when String
                  # If it's a string, assume it's a company name
                  Company.find_by(name: company) || Company.find_by(id: company) || Company.first
                when NilClass
                  # If no company provided, use the first company as fallback (for backward compatibility)
                  Company.first
                else
                  # If it's already a company object, use it as is
                  company
                end

      company&.serial_service_base_url 
    end

    def parse_response(response)
      case response.code.to_i
      when 200..299
        JSON.parse(response.body)
      else
        Rails.logger.error "Serial server error: #{response.code} - #{response.body}"
        { 'status' => 'error', 'message' => response.body }
      end
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse response: #{e.message}"
      { 'status' => 'error', 'message' => 'Invalid response format' }
    end
  end
end