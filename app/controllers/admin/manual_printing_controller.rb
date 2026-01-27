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

    # Check health first
    unless SerialCommunicationService.health_check(company: company)
      render json: {
        success: false,
        message: "Servicio de impresión no disponible o desconectado",
        error: "Health check failed"
      }
      return
    end

    # Select generator based on format AND printer model
    # "bag" is default
    if company.printer_model == 'zebra'
      label_content = case params[:format_type]
                      when "roll"
                        generate_roll_label_zpl(params, ancho_mm, alto_mm, gap_mm)
                      when "box"
                        generate_box_label_zpl(params, ancho_mm, alto_mm, gap_mm)
                      else
                        generate_bag_label_zpl(params, ancho_mm, alto_mm, gap_mm)
                      end
    else
      label_content = case params[:format_type]
                      when "roll"
                        generate_roll_label(params, ancho_mm, alto_mm, gap_mm)
                      when "box"
                        generate_box_label(params, ancho_mm, alto_mm, gap_mm)
                      else
                        generate_bag_label(params, ancho_mm, alto_mm, gap_mm)
                      end
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

  def truncate_text(text, max_length)
    text = text.to_s
    if text.length > max_length
      text[0...max_length]
    else
      text
    end
  end

  def generate_bag_label(params, width, height, gap)
    tspl = [
      "SIZE #{width} mm, #{height} mm",
      "GAP #{gap} mm, 0 mm",
      "DIRECTION 0,0",
      "REFERENCE 0,0",
      "OFFSET 0 mm",
      "CLS",
      "CODEPAGE 1252",
      "TEXT 30,30,\"4\",0,1,1,\"#{truncate_text(sanitize(params[:product_name]), 20)}\"",
      "TEXT 30,70,\"3\",0,1,1,\"Tipo: #{sanitize(params[:bag_type])}\"",
      "TEXT 30,100,\"3\",0,1,1,\"Medida: #{sanitize(params[:bag_measurement])}\"",
      "TEXT 30,130,\"3\",0,1,1,\"Piezas: #{sanitize(params[:pieces_count])}\"",
      "TEXT 30,160,\"3\",0,1,1,\"Peso: #{sanitize(params[:current_weight]) || '0'} kg\"",
      "BARCODE 30,220,\"128\",80,1,0,2,2,\"#{sanitize(params[:barcode_data])}\"",
      "PRINT 1,1"
    ]
    tspl.join("\n") + "\n"
  end

  def generate_roll_label(params, width, height, gap)
    tspl = [
      "SIZE #{width} mm, #{height} mm",
      "GAP #{gap} mm, 0 mm",
      "DIRECTION 0,0",
      "REFERENCE 0,0",
      "OFFSET 0 mm",
      "CLS",
      "CODEPAGE 1252",
      "TEXT 30,30,\"4\",0,1,1,\"#{truncate_text(sanitize(params[:product_name]), 20)}\"",
      "TEXT 30,70,\"3\",0,1,1,\"Rollo: #{sanitize(params[:roll_type])}\"",
      "TEXT 30,100,\"3\",0,1,1,\"Medida: #{sanitize(params[:roll_measurement])}\"",
      "TEXT 30,130,\"3\",0,1,1,\"Piezas: #{sanitize(params[:pieces_count_roll])}\"",
      "TEXT 30,160,\"3\",0,1,1,\"Peso: #{sanitize(params[:current_weight]) || '0'} kg\"",
      "BARCODE 30,220,\"128\",80,1,0,2,2,\"#{sanitize(params[:barcode_data])}\"",
      "PRINT 1,1"
    ]
    tspl.join("\n") + "\n"
  end

  def generate_box_label(params, width, height, gap)
     # Layout slightly condensed for box which has more info
    tspl = [
      "SIZE #{width} mm, #{height} mm",
      "GAP #{gap} mm, 0 mm",
      "DIRECTION 0,0",
      "REFERENCE 0,0",
      "OFFSET 0 mm",
      "CLS",
      "CODEPAGE 1252",
      "TEXT 30,30,\"4\",0,1,1,\"#{truncate_text(sanitize(params[:product_name]), 20)}\"",
      "TEXT 30,70,\"3\",0,1,1,\"Bolsa: #{sanitize(params[:bag_type_box])} #{sanitize(params[:bag_measurement_box])}\"",
      "TEXT 30,100,\"3\",0,1,1,\"Pzs/Caja: #{sanitize(params[:pieces_count_box])}\"",
      "TEXT 30,130,\"3\",0,1,1,\"Paq: #{sanitize(params[:package_count])} x #{sanitize(params[:package_measurement])}\"",
      "TEXT 30,160,\"3\",0,1,1,\"Peso: #{sanitize(params[:current_weight]) || '0'} kg\"",
      "BARCODE 30,220,\"128\",80,1,0,2,2,\"#{sanitize(params[:barcode_data])}\"",
      "PRINT 1,1"
    ]
    tspl.join("\n") + "\n"
  end

  private

  def sanitize(text)
    text.to_s.gsub('"', '\"')
  end

  def truncate_text(text, max_length)
    text = text.to_s
    if text.length > max_length
      text[0...max_length]
    else
      text
    end
  end

  # Métodos para generar etiquetas ZPL (para impresoras Zebra)
  def generate_bag_label_zpl(params, width, height, gap)
    # Convertir dimensiones a unidades ZPL (aproximadamente 8 dpmm para 203 dpi)
    width_dots = (width.to_f * 8).round
    height_dots = (height.to_f * 8).round

    zpl = <<~ZPL
      ^XA
      ^CI28
      ^MMT
      ^PW#{width_dots}
      ^LL#{height_dots}
      ^LS0
      ^FO240,80^A0N,35,35^FD#{truncate_text(sanitize(params[:product_name]), 20)}^FS
      ^FO240,125^A0N,28,28^FDTipo: #{sanitize(params[:bag_type])}^FS
      ^FO240,160^A0N,30,30^FDMedida: #{sanitize(params[:bag_measurement])}^FS
      ^FO240,195^A0N,30,30^FDPiezas: #{sanitize(params[:pieces_count])}^FS
      ^FO240,230^A0N,30,30^FDPeso: #{sanitize(params[:current_weight]) || '0'} kg^FS
      ^FO240,270^BY3,3
      ^BCN,90,Y,N,N
      ^FD#{sanitize(params[:barcode_data])}^FS
      ^PQ1,0,1,Y
      ^XZ
    ZPL

    zpl
  end

  def generate_roll_label_zpl(params, width, height, gap)
    # Convertir dimensiones a unidades ZPL (aproximadamente 8 dpmm para 203 dpi)
    width_dots = (width.to_f * 8).round
    height_dots = (height.to_f * 8).round

    zpl = <<~ZPL
      ^XA
      ^CI28
      ^MMT
      ^PW#{width_dots}
      ^LL#{height_dots}
      ^LS0
      ^FO240,80^A0N,35,35^FD#{truncate_text(sanitize(params[:product_name]), 20)}^FS
      ^FO240,125^A0N,28,28^FDRollo: #{sanitize(params[:roll_type])}^FS
      ^FO240,160^A0N,30,30^FDMedida: #{sanitize(params[:roll_measurement])}^FS
      ^FO240,195^A0N,30,30^FDPiezas: #{sanitize(params[:pieces_count_roll])}^FS
      ^FO240,230^A0N,30,30^FDPeso: #{sanitize(params[:current_weight]) || '0'} kg^FS
      ^FO240,270^BY3,3
      ^BCN,90,Y,N,N
      ^FD#{sanitize(params[:barcode_data])}^FS
      ^PQ1,0,1,Y
      ^XZ
    ZPL

    zpl
  end

  def generate_box_label_zpl(params, width, height, gap)
    # Convertir dimensiones a unidades ZPL (aproximadamente 8 dpmm para 203 dpi)
    width_dots = (width.to_f * 8).round
    height_dots = (height.to_f * 8).round

    zpl = <<~ZPL
      ^XA
      ^CI28
      ^MMT
      ^PW#{width_dots}
      ^LL#{height_dots}
      ^LS0
      ^FO240,80^A0N,35,35^FD#{truncate_text(sanitize(params[:product_name]), 20)}^FS
      ^FO240,125^A0N,28,28^FDBolsa: #{sanitize(params[:bag_type_box])} #{sanitize(params[:bag_measurement_box])}^FS
      ^FO240,160^A0N,30,30^FDPzs/Caja: #{sanitize(params[:pieces_count_box])}^FS
      ^FO240,195^A0N,30,30^FD#{sanitize(params[:package_count])} x #{sanitize(params[:package_measurement])}^FS
      ^FO240,230^A0N,30,30^FDPeso: #{sanitize(params[:current_weight]) || '0'} kg^FS
      ^FO240,270^BY3,3
      ^BCN,90,Y,N,N
      ^FD#{sanitize(params[:barcode_data])}^FS
      ^PQ1,0,1,Y
      ^XZ
    ZPL

    zpl
  end
end
