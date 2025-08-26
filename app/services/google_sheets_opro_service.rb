class GoogleSheetsOproService
  SHEET_ID = "1RK8FZaQZjd-HPcs8ewFxj-YQUZvRB_DO68U25EZ4qDk"
  WORKSHEET_GID = "1973766435"

  def initialize
    @session = GoogleDrive::Session.from_service_account_key(credentials_path)
    @spreadsheet = @session.spreadsheet_by_key(SHEET_ID)
  end

  def sync_production_orders
    Rails.logger.info "Iniciando sincronización de órdenes de producción desde Google Sheet OPRO"
    
    worksheet = @spreadsheet.worksheets.find { |ws| ws.gid == WORKSHEET_GID }
    
    unless worksheet
      Rails.logger.error "No se encontró la hoja de trabajo con GID: #{WORKSHEET_GID}"
      return { success: false, message: "Hoja de trabajo no encontrada" }
    end

    synced_orders = 0
    errors = []

    # Leer las filas del sheet (asumiendo que la primera fila son los encabezados)
    rows = worksheet.rows
    headers = rows[0] # Primera fila son los encabezados
    
    Rails.logger.info "Encabezados encontrados: #{headers.join(', ')}"
    
    rows[1..-1].each_with_index do |row, index|
      next if row.all?(&:blank?) # Saltar filas vacías
      
      begin
        order_data = map_row_to_order_data(headers, row)
        next unless order_data[:stat_opro] == "emitida" # Solo procesar órdenes emitidas
        
        process_production_order(order_data)
        synced_orders += 1
        
        Rails.logger.debug "Procesada orden #{order_data[:no_opro]} exitosamente"
        
      rescue => e
        error_msg = "Error en fila #{index + 2}: #{e.message}"
        Rails.logger.error error_msg
        errors << error_msg
      end
    end

    Rails.logger.info "Sincronización completada. Órdenes sincronizadas: #{synced_orders}, Errores: #{errors.count}"

    {
      success: true,
      synced_orders: synced_orders,
      errors: errors,
      message: "Sincronizadas #{synced_orders} órdenes de producción"
    }

  rescue => e
    Rails.logger.error "Error general en sincronización: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    { 
      success: false, 
      message: "Error en la sincronización: #{e.message}" 
    }
  end

  private

  def credentials_path
    # Buscar el archivo de credenciales en diferentes ubicaciones
    paths = [
      Rails.root.join("config", "credentials.json"),
      Rails.root.join("keys", "credentials.json"),
      Rails.root.join("credentials.json"),
      ENV["GOOGLE_CREDENTIALS_PATH"]
    ].compact

    paths.each do |path|
      return path if File.exist?(path)
    end

    raise "No se encontró el archivo de credenciales de Google. Ubicaciones verificadas: #{paths.join(', ')}"
  end

  def map_row_to_order_data(headers, row)
    data = {}
    
    headers.each_with_index do |header, index|
      case header.downcase
      when "no_opro"
        data[:no_opro] = row[index]
      when "fec_opro"
        data[:fec_opro] = row[index]
      when "ren_orp"
        data[:ren_orp] = row[index]
      when "stat_opro"
        data[:stat_opro] = row[index]&.downcase
      when "clave producto"
        data[:clave_producto] = row[index]
      when "observa", "observaciones", "notas"
        data[:observa] = row[index]
      else
        # Mapear otros campos si es necesario
        data[header.downcase.gsub(" ", "_").to_sym] = row[index]
      end
    end
    
    data
  end

  def process_production_order(order_data)
    # Buscar o crear la orden de producción
    production_order = ProductionOrder.find_by(no_opro: order_data[:no_opro])
    
    if production_order.nil?
      # Crear nueva orden si no existe
      production_order = ProductionOrder.new(no_opro: order_data[:no_opro])
    end
    
    # Si es una nueva orden, necesitamos asignar warehouse y product
    if production_order.new_record?
      production_order.warehouse = find_or_create_default_warehouse
      production_order.product = find_or_create_product(order_data[:clave_producto])
      production_order.quantity_requested = 1 # Default, se puede ajustar
      production_order.priority = "medium" # Default
      production_order.status = map_opro_status(order_data[:stat_opro])
    end

    # Actualizar campos específicos de OPRO
    production_order.assign_attributes(
      fecha_completa: parse_fecha(order_data[:fec_opro]),
      lote_referencia: production_order.generate_lote_from_fecha(order_data[:fec_opro]),
      ren_orp: order_data[:ren_orp],
      stat_opro: order_data[:stat_opro],
      notes: order_data[:observa]
    )

    # Extraer datos de la clave producto (ej: "BOPPTRANS 35 / 420" -> 35 micras, 420 mm)
    micras, ancho_mm = extract_product_specs(order_data[:clave_producto])
    
    if production_order.save
      # Solo crear packing record básico con los datos mínimos disponibles
      update_basic_packing_record(production_order, order_data[:clave_producto], micras, ancho_mm)
    else
      Rails.logger.error "Error al guardar ProductionOrder #{order_data[:no_opro]}: #{production_order.errors.full_messages}"
      raise "Error al guardar orden: #{production_order.errors.full_messages.join(', ')}"
    end

    production_order
  end

  def find_or_create_default_warehouse
    Warehouse.first || Warehouse.create!(name: "Almacén Principal", location: "Principal")
  end

  def find_or_create_product(clave_producto)
    return Product.first if clave_producto.blank?
    
    product = Product.find_by(name: clave_producto)
    return product if product

    # Crear producto si no existe
    Product.create!(
      name: clave_producto,
      description: "Producto importado desde OPRO",
      price: 0,
      stock_quantity: 0
    )
  end

  def map_opro_status(stat_opro)
    case stat_opro&.downcase
    when "emitida"
      "pending"
    when "en_proceso"
      "in_progress"
    when "completada"
      "completed"
    when "cancelada"
      "cancelled"
    else
      "pending"
    end
  end

  def parse_fecha(fecha_str)
    return nil if fecha_str.blank?
    Date.parse(fecha_str.to_s) rescue nil
  end

  def extract_product_specs(clave_producto)
    return [nil, nil] if clave_producto.blank?
    
    # Buscar patrón como "BOPPTRANS 35 / 420" donde 35 son micras y 420 es ancho en mm
    match = clave_producto.match(/(\d+)\s*\/\s*(\d+)/)
    if match
      micras = match[1].to_i
      ancho_mm = match[2].to_i
      return [micras, ancho_mm]
    end

    # Buscar solo micras como "35"
    match = clave_producto.match(/(\d+)/)
    if match
      return [match[1].to_i, nil]
    end

    [nil, nil]
  end

  def update_basic_packing_record(production_order, clave_producto, micras, ancho_mm)
    # Buscar o crear packing record solo si no existe
    return if production_order.packing_records.any?
    
    # Crear un packing record básico con datos mínimos
    packing_record = production_order.packing_records.build(
      lote: production_order.lote_referencia || "LOTE-#{production_order.no_opro}",
      cve_prod: clave_producto || "BOPPTRANS 35 / 420",
      peso_bruto: 0.0,
      peso_neto: 0.0,
      metros_lineales: 0.0,
      consecutivo: 1,
      micras: micras,
      ancho_mm: ancho_mm
    )
    
    packing_record.save!
  end
end