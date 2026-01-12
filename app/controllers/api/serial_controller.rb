# frozen_string_literal: true

class Api::SerialController < ApplicationController
  # before_action :authenticate_admin!  # Comentado para testing
  skip_before_action :authenticate_user_or_admin!  # Para permitir acceso a la API serial
  skip_before_action :verify_authenticity_token   # Para APIs sin CSRF
  
  def health
    if SerialCommunicationService.health_check(company: current_company)
      render json: { status: 'healthy', message: 'Serial server is running' }
    else
      render json: { status: 'error', message: 'Serial server is not available' }, status: 500
    end
  end

  def status
    status_data = SerialCommunicationService.status(company: current_company)
    render json: status_data
  end

  def ports
    ports = SerialCommunicationService.list_serial_ports(company: current_company)
    render json: { status: 'success', ports: ports }
  end

  def connect_scale
    port = params[:port] || 'COM3'
    baudrate = params[:baudrate]&.to_i || 115200
    
    if SerialCommunicationService.connect_scale(port: port, baudrate: baudrate, company: current_company)
      render json: { status: 'success', message: 'Scale connected successfully' }
    else
      render json: { status: 'error', message: 'Failed to connect scale' }, status: 500
    end
  end

  def disconnect_scale
    if SerialCommunicationService.disconnect_scale(company: current_company)
      render json: { status: 'success', message: 'Scale disconnected successfully' }
    else
      render json: { status: 'error', message: 'Failed to disconnect scale' }, status: 500
    end
  end

  def start_scale
    if SerialCommunicationService.start_scale_reading(company: current_company)
      render json: { status: 'success', message: 'Scale reading started' }
    else
      render json: { status: 'error', message: 'Failed to start scale reading' }, status: 500
    end
  end

  def stop_scale
    if SerialCommunicationService.stop_scale_reading(company: current_company)
      render json: { status: 'success', message: 'Scale reading stopped' }
    else
      render json: { status: 'error', message: 'Failed to stop scale reading' }, status: 500
    end
  end

  def read_weight
    reading = SerialCommunicationService.read_scale_weight(company: current_company)
    
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
    reading = SerialCommunicationService.get_last_reading(company: current_company)
    
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
    readings = SerialCommunicationService.get_latest_readings(company: current_company)
    render json: { status: 'success', readings: readings }
  end

  def connect_printer
    if SerialCommunicationService.connect_printer(company: current_company)
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

    if SerialCommunicationService.print_label(content, ancho_mm: ancho_mm, alto_mm: alto_mm, company: current_company)
      render json: { status: 'success', message: 'Label printed successfully' }
    else
      render json: { status: 'error', message: 'Failed to print label' }, status: 500
    end
  end

  def test_printer
    ancho_mm = params[:ancho_mm]&.to_i || 80
    alto_mm = params[:alto_mm]&.to_i || 50
    
    if SerialCommunicationService.test_printer(ancho_mm: ancho_mm, alto_mm: alto_mm, company: current_company)
      render json: { status: 'success', message: 'Printer test executed successfully' }
    else
      render json: { status: 'error', message: 'Failed to execute printer test' }, status: 500
    end
  end

  def disconnect_printer
    if SerialCommunicationService.disconnect_printer(company: current_company)
      render json: { status: 'success', message: 'Printer disconnected successfully' }
    else
      render json: { status: 'error', message: 'Failed to disconnect printer' }, status: 500
    end
  end

  # Endpoint especial para obtener peso con timeout para procesos de pesaje
  def get_weight_now
    timeout = params[:timeout]&.to_i || 10

    reading = SerialCommunicationService.get_weight_with_timeout(timeout_seconds: timeout, company: current_company)

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

  # Endpoint para obtener información del dispositivo serial
  def device_info
    company = current_company
    if company
      render json: {
        status: 'success',
        device_id: company.serial_device_id,
        auth_token: company.serial_auth_token
      }
    else
      render json: { status: 'error', message: 'No company found' }, status: 404
    end
  end

  def current_company
    # Try to identify the company based on the current user context
    # This assumes there's a current_admin or current_user method available
    if current_admin
      current_admin.company
    elsif current_user
      current_user.company
    else
      # Fallback to the first company if no user context is available
      Company.first
    end
  end
end