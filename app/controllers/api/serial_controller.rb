# frozen_string_literal: true

class Api::SerialController < ApplicationController
  # before_action :authenticate_admin!  # Comentado para testing
  skip_before_action :authenticate_user_or_admin!  # Para permitir acceso a la API serial
  skip_before_action :verify_authenticity_token   # Para APIs sin CSRF
  
  # Add CORS headers for all actions
  before_action :set_cors_headers
  
  # Handle preflight OPTIONS requests
  before_action :handle_preflight, only: [:health, :ports, :connect_scale, :disconnect_scale, 
                                          :start_scale, :stop_scale, :read_weight, :last_reading,
                                          :latest_readings, :connect_printer, :print_label,
                                          :test_printer, :disconnect_printer, :get_weight_now]
  
  def handle_preflight
    if request.method == 'OPTIONS'
      set_cors_headers
      render plain: '', content_type: 'text/plain'
    end
  end

  def health
    response = SerialCommunicationService.health_check
    if response
      render json: response
    else
      render json: { status: 'error', message: 'Serial server is not available' }, status: 503
    end
  end

  def ports
    ports = SerialCommunicationService.list_serial_ports
    render json: { status: 'success', ports: ports }
  end

  def connect_scale
    port = params[:port] || 'COM3'
    baudrate = params[:baudrate]&.to_i || 115200
    
    if SerialCommunicationService.connect_scale(port: port, baudrate: baudrate)
      render json: { status: 'success', message: 'Scale connected successfully' }
    else
      render json: { status: 'error', message: 'Failed to connect scale' }, status: 500
    end
  end

  def disconnect_scale
    if SerialCommunicationService.disconnect_scale
      render json: { status: 'success', message: 'Scale disconnected successfully' }
    else
      render json: { status: 'error', message: 'Failed to disconnect scale' }, status: 500
    end
  end

  def start_scale
    if SerialCommunicationService.start_scale_reading
      render json: { status: 'success', message: 'Scale reading started' }
    else
      render json: { status: 'error', message: 'Failed to start scale reading' }, status: 500
    end
  end

  def stop_scale
    if SerialCommunicationService.stop_scale_reading
      render json: { status: 'success', message: 'Scale reading stopped' }
    else
      render json: { status: 'error', message: 'Failed to stop scale reading' }, status: 500
    end
  end

  def read_weight
    reading = SerialCommunicationService.read_scale_weight
    
    if reading
      render json: { 
        status: 'success', 
        weight: reading[:weight], 
        timestamp: reading[:timestamp] 
      }
    else
      render json: { status: 'error', message: 'No weight reading available' }, status: 404
    end
  end

  def last_reading
    reading = SerialCommunicationService.get_last_reading
    
    if reading
      render json: { 
        status: 'success', 
        weight: reading[:weight], 
        timestamp: reading[:timestamp] 
      }
    else
      render json: { status: 'error', message: 'No readings available' }, status: 404
    end
  end

  def latest_readings
    readings = SerialCommunicationService.get_latest_readings
    render json: { status: 'success', readings: readings }
  end

  def connect_printer
    if SerialCommunicationService.connect_printer
      render json: { status: 'success', message: 'Printer connected successfully' }
    else
      render json: { status: 'error', message: 'Failed to connect printer' }, status: 500
    end
  end

  def print_label
    content = params[:content]
    ancho_mm = params[:ancho_mm]&.to_i || 80
    alto_mm = params[:alto_mm]&.to_i || 50
    
    if content.blank?
      render json: { status: 'error', message: 'Content is required' }, status: 400
      return
    end

    if SerialCommunicationService.print_label(content, ancho_mm: ancho_mm, alto_mm: alto_mm)
      render json: { status: 'success', message: 'Label printed successfully' }
    else
      render json: { status: 'error', message: 'Failed to print label' }, status: 500
    end
  end

  def test_printer
    ancho_mm = params[:ancho_mm]&.to_i || 80
    alto_mm = params[:alto_mm]&.to_i || 50
    
    if SerialCommunicationService.test_printer(ancho_mm: ancho_mm, alto_mm: alto_mm)
      render json: { status: 'success', message: 'Printer test executed successfully' }
    else
      render json: { status: 'error', message: 'Failed to execute printer test' }, status: 500
    end
  end

  def disconnect_printer
    if SerialCommunicationService.disconnect_printer
      render json: { status: 'success', message: 'Printer disconnected successfully' }
    else
      render json: { status: 'error', message: 'Failed to disconnect printer' }, status: 500
    end
  end

  # Endpoint especial para obtener peso en tiempo real con polling
  def get_weight_now
    timeout = params[:timeout]&.to_i || 10
    
    reading = SerialCommunicationService.get_weight_with_timeout(timeout_seconds: timeout)
    
    if reading
      render json: { 
        status: 'success', 
        weight: reading['weight'], 
        timestamp: reading['timestamp'] 
      }
    else
      render json: { status: 'error', message: 'No weight reading within timeout' }, status: 408
    end
  end

  private

  def set_cors_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, PATCH, DELETE, OPTIONS'
    headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept, Authorization'
    headers['Access-Control-Max-Age'] = '1728000'
  end
end