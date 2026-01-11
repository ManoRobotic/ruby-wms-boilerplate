class SerialConnectionChannel < ApplicationCable::Channel
  def subscribed
    @device_id = params[:device_id]
    if @device_id.blank?
      reject
      return
    end

    # Usamos un nombre de stream simple y predecible.
    # Tanto el frontend como el cliente de Python se suscribirán al mismo stream.
    stream_from "serial_channel_#{@device_id}"

    logger.info "Cliente suscrito a SerialConnectionChannel, escuchando en 'serial_channel_#{@device_id}'"

    # Si el que se conecta es el script de Python (identificado por ser una Compañía),
    # le enviamos la configuración guardada en la base de datos.
    if current_user_or_admin.is_a?(Company)
      send_initial_config(current_user_or_admin)
    end
  end

  # Esta acción es llamada por el cliente de Python para enviar sus actualizaciones
  # (lista de puertos, peso, etc.)
  def receive(data)
    # Simplemente retransmitimos los datos a todos los que escuchan en este stream.
    # El frontend recibirá esto y actualizará la UI.
    ActionCable.server.broadcast("serial_channel_#{@device_id}", data.deep_symbolize_keys)
  end

  # Método para manejar comandos desde el servidor Rails al cliente Python
  def connect_scale(data)
    # Reenviar el comando al cliente Python
    ActionCable.server.broadcast("serial_channel_#{@device_id}", data.deep_symbolize_keys)
  end

  def disconnect_scale(data)
    # Reenviar el comando al cliente Python
    ActionCable.server.broadcast("serial_channel_#{@device_id}", data.deep_symbolize_keys)
  end

  def start_scale_reading(data)
    # Reenviar el comando al cliente Python
    ActionCable.server.broadcast("serial_channel_#{@device_id}", data.deep_symbolize_keys)
  end

  def stop_scale_reading(data)
    # Reenviar el comando al cliente Python
    ActionCable.server.broadcast("serial_channel_#{@device_id}", data.deep_symbolize_keys)
  end

  def connect_printer(data)
    # Reenviar el comando al cliente Python
    ActionCable.server.broadcast("serial_channel_#{@device_id}", data.deep_symbolize_keys)
  end

  def print_label(data)
    # Reenviar el comando al cliente Python
    ActionCable.server.broadcast("serial_channel_#{@device_id}", data.deep_symbolize_keys)
  end

  def test_printer(data)
    # Reenviar el comando al cliente Python
    ActionCable.server.broadcast("serial_channel_#{@device_id}", data.deep_symbolize_keys)
  end

  def disconnect_printer(data)
    # Reenviar el comando al cliente Python
    ActionCable.server.broadcast("serial_channel_#{@device_id}", data.deep_symbolize_keys)
  end

  # Método para manejar actualizaciones de puertos
  def ports_update(data)
    # Este método se llama cuando se recibe un mensaje con action: 'ports_update'
    # No es necesario hacer nada aquí ya que el mensaje se retransmite en el método receive
    Rails.logger.info "Puertos actualizados recibidos: #{data}"
  end

  # Método para manejar actualizaciones de peso
  def weight_update(data)
    # Este método se llama cuando se recibe un mensaje con action: 'weight_update'
    # No es necesario hacer nada aquí ya que el mensaje se retransmite en el método receive
    Rails.logger.info "Peso actualizado recibido: #{data}"
  end

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
      ActionCable.server.broadcast("serial_channel_#{@device_id}", set_config_message)
    end
  end

  def unsubscribed
    # Limpieza si es necesario.
  end

  private

  def send_initial_config(company)
    config = {
      action: 'set_config',
      scale_port: company.serial_port,
      printer_port: company.printer_port
    }
    # Usamos broadcast al stream nombrado para enviar la config inicial.
    ActionCable.server.broadcast("serial_channel_#{@device_id}", config)
    logger.info "Enviada configuración inicial a serial_channel_#{@device_id}"
  end
end