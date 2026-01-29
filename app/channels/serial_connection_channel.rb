class SerialConnectionChannel < ApplicationCable::Channel
  def subscribed
    @device_id = params[:device_id]
    if @device_id.blank?
      reject
      return
    end

    # El stream ahora es único por compañía + dispositivo para aislamiento total.
    stream_from "serial_channel_#{current_company_id}_#{@device_id}"

    logger.info "Cliente suscrito a SerialConnectionChannel (Compañía: #{current_company_id}), escuchando en 'serial_channel_#{current_company_id}_#{@device_id}'"

    # Si el que se conecta es el script de Python (identificado por ser una Compañía),
    # le enviamos la configuración guardada en la base de datos.
    if current_user_or_admin.is_a?(Company)
      send_initial_config(current_user_or_admin)
    else
      # Si es un usuario regular (frontend), buscamos la compañía por el device_id
      # para enviar la configuración guardada
      company = Company.find_by(serial_device_id: @device_id)
      if company
        send_initial_config(company)
      end
    end
  end

  # Esta acción es llamada por el cliente de Python para enviar sus actualizaciones
  # (lista de puertos, peso, etc.)
  def receive(data)
    # Simplemente retransmitimos los datos a todos los que escuchan en este stream.
    # El frontend recibirá esto y actualizará la UI.
    action = data['action'] || data['type'] || 'unknown'
    Rails.logger.info "SerialConnectionChannel receive called with action/type: #{action}"

    begin
      # Only broadcast if there's actual data to send
      if data && !data.empty?
        # Log specific information for ports_update messages
        if action == 'ports_update'
          Rails.logger.info "SerialConnectionChannel received ports_update with #{data['ports']&.length || 0} ports"
        end

        # Handle diagnostic ping
        if action == 'ping'
          Rails.logger.info "SerialConnectionChannel: Diagnostic ping received, broadcasting to Python..."
        end

        # Use async broadcast to prevent blocking
        # Make sure to preserve the action type when broadcasting
        broadcast_data = data.deep_symbolize_keys
        # Ensure 'action' is present for the JS router if it came in as 'type'
        broadcast_data[:action] ||= action if action != 'unknown'
        
        ActionCable.server.broadcast("serial_channel_#{current_company_id}_#{@device_id}", broadcast_data)
        Rails.logger.info "SerialConnectionChannel broadcast successful for: #{action}"
      end
    rescue => e
      Rails.logger.error "SerialConnectionChannel error broadcasting message: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  # Acción para solicitar actualización de puertos desde el frontend
  def request_ports(data = {})
    Rails.logger.info "SerialConnectionChannel: request_ports llamado por el cliente, retransmitiendo a Python..."
    # Retransmitimos un mensaje de tipo request_ports para que el servidor Python lo capture
    ActionCable.server.broadcast("serial_channel_#{current_company_id}_#{@device_id}", { action: 'request_ports', timestamp: Time.current })
  end

  # Método para manejar comandos desde el servidor Rails al cliente Python
  def connect_scale(data)
    # Reenviar el comando al cliente Python
    ActionCable.server.broadcast("serial_channel_#{current_company_id}_#{@device_id}", data.deep_symbolize_keys)
  end

  def disconnect_scale(data)
    # Reenviar el comando al cliente Python
    ActionCable.server.broadcast("serial_channel_#{current_company_id}_#{@device_id}", data.deep_symbolize_keys)
  end

  def start_scale_reading(data)
    # Reenviar el comando al cliente Python
    ActionCable.server.broadcast("serial_channel_#{current_company_id}_#{@device_id}", data.deep_symbolize_keys)
  end

  def stop_scale_reading(data)
    # Reenviar el comando al cliente Python
    ActionCable.server.broadcast("serial_channel_#{current_company_id}_#{@device_id}", data.deep_symbolize_keys)
  end

  def connect_printer(data)
    # Reenviar el comando al cliente Python
    ActionCable.server.broadcast("serial_channel_#{current_company_id}_#{@device_id}", data.deep_symbolize_keys)
  end

  def print_label(data)
    # Reenviar el comando al cliente Python
    ActionCable.server.broadcast("serial_channel_#{current_company_id}_#{@device_id}", data.deep_symbolize_keys)
  end

  def test_printer(data)
    # Reenviar el comando al cliente Python
    ActionCable.server.broadcast("serial_channel_#{current_company_id}_#{@device_id}", data.deep_symbolize_keys)
  end

  def disconnect_printer(data)
    # Reenviar el comando al cliente Python
    ActionCable.server.broadcast("serial_channel_#{current_company_id}_#{@device_id}", data.deep_symbolize_keys)
  end

  # Note: All messages are handled in the receive method to ensure proper broadcasting
  # Specific action handlers are not needed here as the receive method broadcasts all messages

  # Esta acción es llamada por el frontend (JS) para actualizar la configuración.
  def update_config(data)
    # Como el JS no está autenticado como una Compañía, la buscamos usando el device_id
    # que ya está asociado a la conexión de este canal.
    company = Company.find_by(serial_device_id: @device_id)
    if company
      logger.info "Actualizando config para la compañía #{company.name} con: #{data.inspect}"
      company.update(
        serial_port: data['scale_port'],
        printer_port: data['printer_port']
      )

      # Construimos un mensaje de 'set_config' y lo enviamos al stream.
      # El script de Python lo recibirá y aplicará los cambios.
      set_config_message = {
        action: 'set_config',
        scale_port: data['scale_port'],
        printer_port: data['printer_port']
      }
      ActionCable.server.broadcast("serial_channel_#{current_company_id}_#{@device_id}", set_config_message)
    end
  end

  # Método explícito para manejar actualizaciones de puertos desde el cliente Python
  def ports_update(data)
    # Este método maneja las actualizaciones de puertos desde el cliente Python
    Rails.logger.info "SerialConnectionChannel received ports_update with #{data['ports']&.length || 0} ports"
    Rails.logger.info "Scale port: #{data['scale_port']}, Scale connected: #{data['scale_connected']}"
    Rails.logger.info "Printer port: #{data['printer_port']}, Printer connected: #{data['printer_connected']}"

    # Persistimos los puertos en la base de datos si el script nos dice que están ahí.
    # Solo lo hacemos si el dispositivo está REALMENTE conectado para no guardar basura.
    company = Company.find_by(serial_device_id: @device_id)
    if company
      updates = {}
      if data['scale_port'].present? && data['scale_connected'] == true
        updates[:serial_port] = data['scale_port']
      end
      
      if data['printer_port'].present? && data['printer_connected'] == true
        updates[:printer_port] = data['printer_port']
      end
      
      if updates.any?
        company.update(updates)
        Rails.logger.info "Canal Serial: Configuración de puertos VERIFICADA PERSISTIDA en DB para #{company.name}: #{updates}"
      end
    end

    # Retransmit the message to all subscribers
    ActionCable.server.broadcast("serial_channel_#{current_company_id}_#{@device_id}", data.deep_symbolize_keys)
    Rails.logger.info "SerialConnectionChannel broadcast successful for ports_update"
  end

  # Método explícito para manejar actualizaciones de peso desde el cliente Python
  def weight_update(data)
    # Este método maneja las actualizaciones de peso desde el cliente Python
    Rails.logger.info "Peso actualizado recibido: #{data['weight']} en #{data['timestamp']}"

    # Retransmit the message to all subscribers
    ActionCable.server.broadcast("serial_channel_#{current_company_id}_#{@device_id}", data.deep_symbolize_keys)
    Rails.logger.info "SerialConnectionChannel broadcast successful for weight_update"
  end

  # Método explícito para manejar actualizaciones de estado desde el cliente Python
  def status_update(data)
    # Este método maneja las actualizaciones de estado desde el cliente Python
    Rails.logger.info "Estado actualizado recibido: #{data}"

    # Retransmit the message to all subscribers
    ActionCable.server.broadcast("serial_channel_#{current_company_id}_#{@device_id}", data.deep_symbolize_keys)
    Rails.logger.info "SerialConnectionChannel broadcast successful for status_update"
  end

  def unsubscribed
    # Limpieza si es necesario.
  end

  private

  def current_company_id
    @current_company_id ||= if current_user_or_admin.is_a?(Company)
      current_user_or_admin.id
    else
      current_user_or_admin.company_id
    end
  end

  def send_initial_config(company)
    config = {
      action: 'set_config',
      scale_port: company.serial_port,
      printer_port: company.printer_port
    }
    # Usamos broadcast al stream nombrado para enviar la config inicial.
    ActionCable.server.broadcast("serial_channel_#{current_company_id}_#{@device_id}", config)
    logger.info "Enviada configuración inicial a serial_channel_#{current_company_id}_#{@device_id}"
  end
end