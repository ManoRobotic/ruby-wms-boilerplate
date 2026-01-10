class SerialConnectionChannel < ApplicationCable::Channel
  # Llamado cuando un cliente (JS o Python) se suscribe al canal
  def subscribed
    # current_user_or_admin es el objeto Company o Admin/User verificado en connection.rb
    # Usamos el device_id para crear un stream privado.
    # El frontend y el script de python deben usar el mismo device_id.
    @device_id = params[:device_id]
    stream_for @device_id
    
    logger.info "Cliente suscrito a SerialConnectionChannel con device_id: #{@device_id}"

    # Si el que se conecta es el script de Python, le enviamos la configuración guardada
    # Asumimos que el script de Python se identifica por el objeto Company.
    if current_user_or_admin.is_a?(Company)
      send_initial_config(current_user_or_admin)
    end
  end

  # Llamado cuando el cliente de Python envía datos (actualizaciones de peso, lista de puertos, etc.)
  # O cuando el frontend envía un comando para imprimir (aunque es mejor una acción dedicada).
  def receive(data)
    # Simplemente retransmitimos los datos a todos los clientes en el mismo stream (el frontend).
    SerialConnectionChannel.broadcast_to(@device_id, data)
    logger.info "Retransmitiendo datos a #{@device_id}: #{data.inspect}"
  end

  # Nueva acción, llamada por el frontend para actualizar la configuración
  def update_config(data)
    company = Company.find_by(serial_device_id: @device_id)

    if company
      logger.info "Actualizando configuración para la compañía #{company.name} con data: #{data.inspect}"
      company.update(
        serial_port: data['scale_port'],
        printer_port: data['printer_port']
      )
      
      # Después de guardar, enviamos la nueva configuración al script de Python.
      set_config_message = { 
        action: 'set_config', 
        scale_port: data['scale_port'],
        printer_port: data['printer_port']
      }
      SerialConnectionChannel.broadcast_to(@device_id, set_config_message)
      
      logger.info "Enviando nueva configuración al dispositivo #{@device_id}"
    else
      logger.warn "No se encontró compañía para el device_id #{@device_id} al intentar actualizar config."
    end
  end

  def unsubscribed
    logger.info "Cliente con device_id: #{@device_id} desuscrito."
  end

  private

  def send_initial_config(company)
    config = {
      action: 'set_config',
      scale_port: company.serial_port,
      printer_port: company.printer_port
    }
    ActionCable.server.broadcast(@device_id, config)
    logger.info "Enviada configuración inicial a #{@device_id}: #{config.inspect}"
  end
end
