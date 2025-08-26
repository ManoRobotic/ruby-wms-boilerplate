require 'digest'

class AdminGoogleSheetsService
  def initialize(admin)
    @admin = admin
    validate_configuration!
    @session = GoogleDrive::Session.from_service_account_key(StringIO.new(@admin.google_credentials))
    @spreadsheet = @session.spreadsheet_by_key(@admin.sheet_id)
  end

  def check_for_changes
    Rails.logger.info "Verificando cambios en Google Sheet para admin: #{@admin.email}"
    
    worksheet = find_opro_worksheet
    return { has_changes: false, message: "No se encontró hoja de trabajo" } unless worksheet

    # Obtener información básica de la hoja
    current_row_count = worksheet.num_rows
    
    # Si nunca se ha sincronizado, definitivamente hay cambios
    if @admin.last_sync_at.nil?
      return { 
        has_changes: true, 
        message: "Primera sincronización", 
        details: "No hay sincronización previa registrada",
        current_rows: current_row_count
      }
    end

    # Calcular checksum de los datos actuales
    current_checksum = calculate_worksheet_checksum(worksheet)
    
    # Comparar con el último checksum
    if @admin.last_sync_checksum != current_checksum
      return { 
        has_changes: true, 
        message: "Datos modificados", 
        details: "Se detectaron cambios en los datos del Google Sheet",
        current_rows: current_row_count,
        last_sync: @admin.last_sync_at,
        last_checksum: @admin.last_sync_checksum,
        current_checksum: current_checksum
      }
    end

    # No hay cambios
    { 
      has_changes: false, 
      message: "Sin cambios", 
      details: "Los datos no han cambiado desde la última sincronización",
      current_rows: current_row_count,
      last_sync: @admin.last_sync_at
    }
  end

  def sync_production_orders(force_sync: false)
    Rails.logger.info "Iniciando sincronización de órdenes de producción desde Google Sheet para admin: #{@admin.email}"

    worksheet = find_opro_worksheet
    
    # Verificar cambios antes de sincronizar (a menos que sea forzado)
    unless force_sync
      # Calcular checksum actual para comparar
      current_checksum = calculate_worksheet_checksum(worksheet)
      
      if @admin.last_sync_at.present? && @admin.last_sync_checksum == current_checksum
        Rails.logger.info "No hay cambios detectados para admin #{@admin.email}, omitiendo sincronización"
        return {
          success: true,
          synced_orders: 0,
          errors: [],
          message: "Sin cambios detectados. Última sincronización: #{@admin.last_sync_at&.strftime('%d/%m/%Y %H:%M')}",
          skipped: true
        }
      end
      
      Rails.logger.info "Cambios detectados para admin #{@admin.email}"
    end
    
    unless worksheet
      Rails.logger.error "No se encontró ninguna hoja de trabajo con datos de OPRO para admin: #{@admin.email}"
      return { success: false, message: "No se encontró una hoja con datos de órdenes de producción. Verifique que tenga columnas como 'no_opro', 'fec_opro', 'stat_opro' o 'clave producto'." }
    end

    Rails.logger.info "Usando hoja de trabajo: '#{worksheet.title}' (GID: #{worksheet.gid}) para admin: #{@admin.email}"

    synced_orders = 0
    errors = []

    # Leer las filas del sheet (asumiendo que la primera fila son los encabezados)
    rows = worksheet.rows
    headers = rows[0] # Primera fila son los encabezados
    
    Rails.logger.info "Encabezados encontrados: #{headers.join(', ')}"
    Rails.logger.info "Total de filas a procesar: #{rows.length - 1}"
    
    # Procesar en lotes para mejor performance
    batch_size = 50
    data_rows = rows[1..-1]
    
    data_rows.each_slice(batch_size).with_index do |batch, batch_index|
      Rails.logger.info "Procesando lote #{batch_index + 1} de #{(data_rows.length.to_f / batch_size).ceil} (#{batch.length} filas)"
      
      batch.each_with_index do |row, row_index|
        absolute_index = (batch_index * batch_size) + row_index
        next if row.all?(&:blank?) # Saltar filas vacías
        
        begin
          order_data = map_row_to_order_data(headers, row)
          # Importar todas las órdenes - usar filtros de la tabla para mostrar/ocultar
          
          process_production_order(order_data)
          synced_orders += 1
          
          # Log progress every 10 orders
          if synced_orders % 10 == 0
            Rails.logger.info "Procesadas #{synced_orders} órdenes..."
          end
          
        rescue => e
          error_msg = "Error en fila #{absolute_index + 2}: #{e.message}"
          Rails.logger.error error_msg
          errors << error_msg
        end
      end
      
      # Small delay between batches to avoid overwhelming the system
      sleep(0.1) if batch_index < (data_rows.length.to_f / batch_size).ceil - 1
    end

    Rails.logger.info "Sincronización completada para admin #{@admin.email}. Órdenes sincronizadas: #{synced_orders}, Errores: #{errors.count}"

    # Actualizar información de tracking
    current_checksum = calculate_worksheet_checksum(worksheet)
    @admin.update!(
      last_sync_at: Time.current,
      last_sync_checksum: current_checksum,
      total_orders_synced: synced_orders
    )

    {
      success: true,
      synced_orders: synced_orders,
      errors: errors,
      message: "Sincronizadas #{synced_orders} órdenes de producción para #{@admin.email}",
      checksum: current_checksum
    }

  rescue => e
    Rails.logger.error "Error general en sincronización para admin #{@admin.email}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    { 
      success: false, 
      message: "Error en la sincronización: #{e.message}" 
    }
  end

  def find_opro_worksheet
    Rails.logger.info "Buscando hoja de trabajo con datos de OPRO para admin: #{@admin.email}"
    
    @spreadsheet.worksheets.each do |ws|
      begin
        # Verificar que la hoja tenga filas
        next if ws.num_rows == 0
        
        headers = ws.rows[0]
        next if headers.blank?
        
        Rails.logger.debug "Verificando hoja '#{ws.title}' con encabezados: #{headers.join(', ')}"
        
        # Si encuentra encabezados que indican datos de OPRO
        if has_opro_headers?(headers)
          Rails.logger.info "¡Encontrada hoja de OPRO! Título: '#{ws.title}', GID: #{ws.gid}"
          return ws
        end
      rescue => e
        Rails.logger.warn "Error al verificar hoja '#{ws.title}': #{e.message}"
        next
      end
    end
    
    # Si no encuentra ninguna hoja específica, usar la primera que tenga datos
    first_worksheet = @spreadsheet.worksheets.find { |ws| ws.num_rows > 0 }
    if first_worksheet
      Rails.logger.info "No se encontró hoja específica de OPRO, usando la primera hoja con datos: '#{first_worksheet.title}'"
      return first_worksheet
    end
    
    Rails.logger.error "No se encontraron hojas de trabajo con datos para admin: #{@admin.email}"
    nil
  end

  private

  def calculate_worksheet_checksum(worksheet)
    # Generar un hash basado en el contenido relevante de la hoja
    begin
      # Obtener todas las filas de datos (sin encabezados)
      rows = worksheet.rows[1..-1] # Saltar encabezados
      
      # Crear un string con los datos relevantes para el checksum
      data_string = rows.map do |row|
        # Solo incluir las primeras columnas relevantes para evitar cambios menores
        # que no afecten las órdenes de producción
        row[0..6].join('|') # Ajustar según las columnas importantes
      end.join("\n")
      
      # Calcular MD5 hash del contenido
      checksum = Digest::MD5.hexdigest(data_string)
      
      Rails.logger.debug "Calculado checksum para #{worksheet.num_rows - 1} filas: #{checksum[0..8]}..."
      checksum
      
    rescue => e
      Rails.logger.error "Error calculando checksum: #{e.message}"
      # Fallback: usar timestamp y número de filas
      "fallback_#{Time.current.to_i}_#{worksheet.num_rows}"
    end
  end

  def has_opro_headers?(headers)
    # Indicadores que sugieren que es una hoja de órdenes de producción
    opro_indicators = [
      'no_opro', 'nro_opro', 'numero_opro', 'opro',
      'fec_opro', 'fecha_opro', 'fecha',
      'stat_opro', 'status_opro', 'estado_opro', 'estado',
      'clave producto', 'clave_producto', 'producto', 'product',
      'ren_orp', 'ren'
    ]
    
    # Convertir encabezados a minúsculas y sin espacios para comparar
    normalized_headers = headers.map { |h| h.to_s.downcase.strip.gsub(/\s+/, '_') }
    
    # Verificar si al menos 2 indicadores están presentes
    matches = opro_indicators.count { |indicator| normalized_headers.include?(indicator) }
    
    Rails.logger.debug "Encontradas #{matches} coincidencias de indicadores OPRO en encabezados"
    matches >= 2
  end

  def validate_configuration!
    unless @admin.google_sheets_configured?
      raise "Admin #{@admin.email} no tiene Google Sheets configurado correctamente"
    end

    unless @admin.validate_google_credentials
      raise "Las credenciales de Google Sheets para #{@admin.email} no son válidas"
    end
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
    ActiveRecord::Base.transaction do
      # Buscar orden por no_opro primero, independientemente del admin
      production_order = ProductionOrder.find_by(no_opro: order_data[:no_opro])
      
      if production_order.nil?
        # Crear nueva orden solo si no existe
        production_order = ProductionOrder.new(
          no_opro: order_data[:no_opro],
          admin_id: @admin.id
        )
      else
        # Transferir propiedad al admin actual si es diferente
        if production_order.admin_id != @admin.id
          Rails.logger.info "Transfiriendo orden #{order_data[:no_opro]} de admin #{production_order.admin_id} a #{@admin.id}"
          production_order.admin_id = @admin.id
        end
      end
    
    # Si es una nueva orden, necesitamos asignar warehouse y product
    if production_order.new_record?
      production_order.warehouse = find_or_create_default_warehouse
      production_order.product = find_or_create_product(order_data[:clave_producto])
      production_order.quantity_requested = 1 # Default, se puede ajustar
      production_order.priority = "medium" # Default
      production_order.status = map_opro_status(order_data[:stat_opro])
      production_order.admin_id = @admin.id
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
      Rails.logger.error "Error al guardar ProductionOrder #{order_data[:no_opro]} para admin #{@admin.email}: #{production_order.errors.full_messages}"
      raise "Error al guardar orden: #{production_order.errors.full_messages.join(', ')}"
    end

      production_order
    end  # End transaction
  end

  def find_or_create_default_warehouse
    # Buscar un warehouse asociado al admin o crear uno por defecto
    Warehouse.first || Warehouse.create!(
      name: "Almacén Principal - #{@admin.email}", 
      location: "Principal"
    )
  end

  def find_or_create_product(clave_producto)
    return Product.first if clave_producto.blank?
    
    product = Product.find_by(name: clave_producto)
    return product if product

    # Crear producto si no existe
    Product.create!(
      name: clave_producto,
      description: "Producto importado desde OPRO - #{@admin.email}",
      price: 0,
      stock_quantity: 0
    )
  end

  def map_opro_status(stat_opro)
    case stat_opro&.downcase&.strip
    when "emitida", "emitido", "nueva", "nuevo", "creada", "creado"
      "pending"
    when "en_proceso", "en proceso", "iniciada", "iniciado", "activa", "activo"
      "in_progress"
    when "completada", "completado", "finalizada", "finalizado", "terminada", "terminado"
      "completed"
    when "cancelada", "cancelado", "anulada", "anulado"
      "cancelled"
    when "programada", "programado", "planificada", "planificado"
      "scheduled"
    when "pausada", "pausado", "suspendida", "suspendido"
      "paused"
    else
      # Si no reconoce el estado, usar "pending" por defecto
      Rails.logger.info "Estado desconocido '#{stat_opro}' mapeado a 'pending' para admin #{@admin.email}"
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