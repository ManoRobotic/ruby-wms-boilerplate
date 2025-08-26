require 'digest'

class IncrementalGoogleSheetsService < AdminGoogleSheetsService
  
  def incremental_sync_production_orders
    Rails.logger.info "Iniciando sincronización incremental para admin: #{@admin.email}"
    
    worksheet = find_opro_worksheet
    unless worksheet
      return { success: false, message: "No se encontró hoja de trabajo" }
    end

    rows = worksheet.rows
    headers = rows[0]
    data_rows = rows[1..-1]
    
    sync_stats = {
      checked: 0,
      updated: 0,
      created: 0,
      skipped: 0,
      errors: []
    }

    # Verificar cada fila individualmente
    data_rows.each_with_index do |row, index|
      sync_stats[:checked] += 1
      row_number = index + 2 # +2 porque empezamos en fila 1 y saltamos headers
      
      begin
        result = process_row_incrementally(headers, row, row_number)
        
        case result[:action]
        when :created
          sync_stats[:created] += 1
        when :updated  
          sync_stats[:updated] += 1
        when :skipped
          sync_stats[:skipped] += 1
        end
        
      rescue => e
        error_msg = "Error en fila #{row_number}: #{e.message}"
        Rails.logger.error error_msg
        sync_stats[:errors] << error_msg
      end
    end

    # Sincronización bidireccional: actualizar Google Sheets con cambios de BD
    bidirectional_sync_result = sync_database_changes_to_sheet(worksheet)
    sync_stats.merge!(bidirectional_sync_result)

    # Actualizar tracking global
    current_checksum = calculate_worksheet_checksum(worksheet)
    @admin.update!(
      last_sync_at: Time.current,
      last_sync_checksum: current_checksum,
      total_orders_synced: sync_stats[:created] + sync_stats[:updated]
    )

    Rails.logger.info "Sincronización incremental completada: #{sync_stats}"

    {
      success: true,
      incremental: true,
      **sync_stats,
      message: build_incremental_message(sync_stats)
    }
  end

  private

  def process_row_incrementally(headers, row, row_number)
    return { action: :skipped } if row.all?(&:blank?)
    
    order_data = map_row_to_order_data(headers, row)
    return { action: :skipped } if order_data[:no_opro].blank?
    
    # Calcular hash de la fila para detectar cambios
    row_hash = calculate_row_hash(row[0..6])  # Primeras 7 columnas importantes
    
    # Buscar orden existente por no_opro independientemente del admin
    production_order = ProductionOrder.find_by(no_opro: order_data[:no_opro])
    
    # Si la orden existe pero pertenece a otro admin, transferir propiedad
    if production_order && production_order.admin_id != @admin.id
      Rails.logger.info "Transfiriendo orden #{order_data[:no_opro]} de admin #{production_order.admin_id} a #{@admin.id}"
      production_order.admin_id = @admin.id
    end

    if production_order
      # Verificar si cambió desde la última vez
      if production_order.last_sheet_update != row_hash
        Rails.logger.debug "Actualizando orden #{order_data[:no_opro]} - cambios detectados"
        update_existing_order(production_order, order_data, row_number, row_hash)
        return { action: :updated, order: production_order }
      else
        return { action: :skipped }
      end
    else
      # Crear nueva orden
      Rails.logger.debug "Creando nueva orden #{order_data[:no_opro]}"
      new_order = create_new_order(order_data, row_number, row_hash)
      return { action: :created, order: new_order }
    end
  end

  def update_existing_order(production_order, order_data, row_number, row_hash)
    ActiveRecord::Base.transaction do
      # Marcar como actualización desde sheet
      production_order.from_sheet_sync = true
      
      # Solo actualizar campos que vienen del sheet (no sobreescribir cambios locales)
      sheet_fields = {
        fecha_completa: parse_fecha(order_data[:fec_opro]),
        lote_referencia: production_order.generate_lote_from_fecha(order_data[:fec_opro]),
        ren_orp: order_data[:ren_orp],
        stat_opro: order_data[:stat_opro],
        notes: order_data[:observa],
        sheet_row_number: row_number,
        last_sheet_update: row_hash
      }
      
      # Solo actualizar status si no fue cambiado localmente
      unless production_order.needs_update_to_sheet?
        sheet_fields[:status] = map_opro_status(order_data[:stat_opro])
      end

      production_order.update!(sheet_fields)
      
      # Actualizar packing record si es necesario
      micras, ancho_mm = extract_product_specs(order_data[:clave_producto])
      update_basic_packing_record(production_order, order_data[:clave_producto], micras, ancho_mm)
    end
  end

  def create_new_order(order_data, row_number, row_hash)
    ActiveRecord::Base.transaction do
      production_order = ProductionOrder.new(
        no_opro: order_data[:no_opro],
        admin_id: @admin.id,
        warehouse: find_or_create_default_warehouse,
        product: find_or_create_product(order_data[:clave_producto]),
        quantity_requested: 1,
        priority: "medium",
        status: map_opro_status(order_data[:stat_opro]),
        fecha_completa: parse_fecha(order_data[:fec_opro]),
        lote_referencia: ProductionOrder.new.generate_lote_from_fecha(order_data[:fec_opro]),
        ren_orp: order_data[:ren_orp],
        stat_opro: order_data[:stat_opro],
        notes: order_data[:observa],
        sheet_row_number: row_number,
        last_sheet_update: row_hash
      )

      production_order.save!
      
      micras, ancho_mm = extract_product_specs(order_data[:clave_producto])
      update_basic_packing_record(production_order, order_data[:clave_producto], micras, ancho_mm)
      
      production_order
    end
  end

  def sync_database_changes_to_sheet(worksheet)
    Rails.logger.info "Sincronizando cambios de BD a Google Sheets..."
    
    # Encontrar órdenes que necesitan actualizar el sheet
    orders_to_update = ProductionOrder.where(
      admin_id: @admin.id,
      needs_update_to_sheet: true
    ).where.not(sheet_row_number: nil)

    updated_to_sheet = 0
    
    orders_to_update.find_each do |order|
      begin
        row_number = order.sheet_row_number
        
        # Mapear status de BD a sheet
        sheet_status = map_db_status_to_sheet(order.status)
        
        # Actualizar celda de status en Google Sheet
        status_column = find_status_column_index(worksheet.rows[0])
        if status_column
          worksheet[row_number, status_column + 1] = sheet_status  # +1 porque Google Sheets es 1-indexed
          worksheet.save
          
          # Marcar como actualizado
          order.update!(needs_update_to_sheet: false)
          updated_to_sheet += 1
          
          Rails.logger.debug "Actualizado status en sheet para orden #{order.no_opro}: #{sheet_status}"
        end
        
      rescue => e
        Rails.logger.error "Error actualizando sheet para orden #{order.no_opro}: #{e.message}"
      end
    end

    { updated_to_sheet: updated_to_sheet }
  end

  def calculate_row_hash(row_data)
    Digest::MD5.hexdigest(row_data.join('|'))
  end

  def find_status_column_index(headers)
    headers.each_with_index do |header, index|
      return index if header.to_s.downcase.match?(/stat|status|estado/)
    end
    nil
  end

  def map_db_status_to_sheet(db_status)
    case db_status
    when "pending" then "emitida"
    when "in_progress" then "en_proceso"
    when "completed" then "completada"
    when "cancelled" then "cancelada"
    when "scheduled" then "programada"
    when "paused" then "pausada"
    else db_status
    end
  end

  def build_incremental_message(stats)
    message_parts = []
    message_parts << "#{stats[:created]} creadas" if stats[:created] > 0
    message_parts << "#{stats[:updated]} actualizadas" if stats[:updated] > 0
    message_parts << "#{stats[:updated_to_sheet]} enviadas a sheet" if stats[:updated_to_sheet] > 0
    message_parts << "#{stats[:skipped]} sin cambios" if stats[:skipped] > 0
    
    if message_parts.any?
      "Sincronización incremental: " + message_parts.join(", ")
    else
      "Sin cambios detectados en sincronización incremental"
    end
  end
end