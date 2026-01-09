class Admin::ManualPrintingController < AdminController
  def index
    # Vista principal de impresión manual
  end

  def connect_printer
    company = current_admin&.company || current_user&.company
    result = SerialCommunicationService.connect_printer(company: company)

    if result
      render json: {
        success: true,
        message: "Impresora conectada exitosamente",
        output: "Connected"
      }
    else
      render json: {
        success: false,
        message: "Error al conectar con la impresora",
        error: "Check server logs or connection"
      }
    end
  end

  def print_test
    # Parámetros del formulario
    company = current_admin&.company || current_user&.company
    
    # Common params
    ancho_mm = params[:ancho_mm].presence || 80
    alto_mm = params[:alto_mm].presence || 50
    gap_mm = params[:gap_mm].presence || 2
    
    # Select generator based on format
    # "bag" is default
    label_content = case params[:format_type]
                    when "roll"
                      generate_roll_label(params, ancho_mm, alto_mm, gap_mm)
                    when "box"
                      generate_box_label(params, ancho_mm, alto_mm, gap_mm)
                    else 
                      generate_bag_label(params, ancho_mm, alto_mm, gap_mm)
                    end

    if SerialCommunicationService.print_label(label_content, ancho_mm: ancho_mm, alto_mm: alto_mm, company: company)
      render json: {
        success: true,
        message: "Etiqueta enviada a imprimir",
        output: "Printed"
      }
    else
      render json: {
        success: false,
        message: "Error al imprimir etiqueta",
        error: "Failed to send to printer service"
      }
    end
  end

  def calibrate_sensor
    # Not directly supported by Service yet, but can be implemented via arbitrary command if needed.
    # For now returning error or stub.
    render json: { success: false, message: "Calibración no soportada remotamente por ahora" }
  end

  def printer_status
    # Placeholder
    render json: { success: true, message: "Estado obtenido", output: "Online" }
  end

  def connect_scale
    company = current_admin&.company || current_user&.company
    result = SerialCommunicationService.connect_scale(company: company)

    if result
      render json: {
        success: true,
        message: "Báscula conectada exitosamente",
        output: "Connected"
      }
    else
      render json: {
        success: false,
        message: "Error al conectar con la báscula",
        error: "Connection failed"
      }
    end
  end

  def read_weight
    company = current_admin&.company || current_user&.company
    result = SerialCommunicationService.read_weight(company: company)

    if result && result['weight']
      render json: {
        success: true,
        message: "Peso leído correctamente",
        weight: result['weight'],
        output: result.to_s
      }
    else
      render json: {
        success: false,
        message: "Error al leer peso",
        error: "No reading",
        weight: 0.0
      }
    end
  end

  private

  def sanitize(text)
    text.to_s.gsub('"', '\"')
  end

  def generate_bag_label(params, width, height, gap)
    tspl = [
      "SIZE #{width} mm, #{height} mm",
      "GAP #{gap} mm, 0 mm",
      "DIRECTION 1,0",
      "CLS",
      "TEXT 150,10,\"3\",0,1,1,\"#{sanitize(params[:product_name])}\"",
      "TEXT 150,50,\"2\",0,1,1,\"Tipo: #{sanitize(params[:bag_type])}\"",
      "TEXT 150,80,\"2\",0,1,1,\"Medida: #{sanitize(params[:bag_measurement])}\"",
      "TEXT 150,110,\"2\",0,1,1,\"Piezas: #{sanitize(params[:pieces_count])}\"",
      "TEXT 150,140,\"2\",0,1,1,\"Peso: #{sanitize(params[:current_weight]) || '0'} kg\"",
      "BARCODE 150,180,\"128\",50,1,0,2,2,\"#{sanitize(params[:barcode_data])}\"",
      "PRINT 1,1"
    ]
    tspl.join("\n") + "\n"
  end

  def generate_roll_label(params, width, height, gap)
    tspl = [
      "SIZE #{width} mm, #{height} mm",
      "GAP #{gap} mm, 0 mm",
      "DIRECTION 1,0",
      "CLS",
      "TEXT 150,10,\"3\",0,1,1,\"#{sanitize(params[:product_name])}\"",
      "TEXT 150,50,\"2\",0,1,1,\"Rollo: #{sanitize(params[:roll_type])}\"",
      "TEXT 150,80,\"2\",0,1,1,\"Medida: #{sanitize(params[:roll_measurement])}\"",
      "TEXT 150,110,\"2\",0,1,1,\"Piezas: #{sanitize(params[:pieces_count_roll])}\"",
      "TEXT 150,140,\"2\",0,1,1,\"Peso: #{sanitize(params[:current_weight]) || '0'} kg\"",
      "BARCODE 150,180,\"128\",50,1,0,2,2,\"#{sanitize(params[:barcode_data])}\"",
      "PRINT 1,1"
    ]
    tspl.join("\n") + "\n"
  end

  def generate_box_label(params, width, height, gap)
     # Layout slightly condensed for box which has more info
    tspl = [
      "SIZE #{width} mm, #{height} mm",
      "GAP #{gap} mm, 0 mm",
      "DIRECTION 1,0",
      "CLS",
      "TEXT 150,10,\"3\",0,1,1,\"#{sanitize(params[:product_name])}\"",
      "TEXT 150,40,\"2\",0,1,1,\"Caja - Bolsa: #{sanitize(params[:bag_type_box])} #{sanitize(params[:bag_measurement_box])}\"",
      "TEXT 150,70,\"2\",0,1,1,\"Pzs/Caja: #{sanitize(params[:pieces_count_box])}\"",
      "TEXT 150,100,\"2\",0,1,1,\"Paquetes: #{sanitize(params[:package_count])} x #{sanitize(params[:package_measurement])}\"",
      "TEXT 150,130,\"2\",0,1,1,\"Peso: #{sanitize(params[:current_weight]) || '0'} kg\"",
      "BARCODE 150,170,\"128\",50,1,0,2,2,\"#{sanitize(params[:barcode_data])}\"",
      "PRINT 1,1"
    ]
    tspl.join("\n") + "\n"
  end
end
