class SyncExcelDataJob < ApplicationJob
  queue_as :default

  # Job para sincronizar datos desde merged.xlsx cada 5 minutos
  # Actualiza automáticamente las órdenes de producción con datos del Excel
  
  def perform
    Rails.logger.info "🔄 [SyncExcelDataJob] Iniciando sincronización desde merged.xlsx..."
    
    start_time = Time.current
    
    begin
      # Verificar que el archivo existe
      unless File.exist?('merged.xlsx')
        Rails.logger.warn "⚠️  [SyncExcelDataJob] Archivo merged.xlsx no encontrado"
        return
      end
      
      # Obtener la marca de tiempo del archivo para verificar cambios
      file_modified_time = File.mtime('merged.xlsx')
      last_sync_time = Rails.cache.read('excel_last_sync_time')

      # Rails.logger.info "DEBUG: file_modified_time: #{file_modified_time}, last_sync_time: #{last_sync_time}"

      # Solo procesar si el archivo cambió o es la primera vez
      if last_sync_time.nil? || file_modified_time > last_sync_time
        Rails.logger.info "📁 [SyncExcelDataJob] Archivo modificado o primera ejecución, procesando cambios..."
        
        result = process_excel_updates
        
        # Guardar la marca de tiempo de la última sincronización
        Rails.cache.write('excel_last_sync_time', file_modified_time)
        
        Rails.logger.info "✅ [SyncExcelDataJob] Sincronización completada: #{result[:updated]} actualizadas, #{result[:created]} creadas, #{result[:errors]} errores"
        
        # Enviar notificación si hay cambios significativos
        if result[:updated] > 0 || result[:created] > 0
          broadcast_sync_notification(result)
        end
        
      else
        Rails.logger.info "📋 [SyncExcelDataJob] Sin cambios en merged.xlsx, omitiendo procesamiento"
      end
      
    rescue => e
      Rails.logger.error "❌ [SyncExcelDataJob] Error en sincronización: #{e.message}"
      Rails.logger.error "   Backtrace: #{e.backtrace.first(3).join('; ')}"
      
      # Notificar error a administradores
      notify_sync_error(e)
    end
    
    execution_time = Time.current - start_time
    Rails.logger.info "⏱️  [SyncExcelDataJob] Ejecutado en #{execution_time.round(2)} segundos"
    
    # Programar el próximo job en 5 minutos (reducir frecuencia)
    SyncExcelDataJob.set(wait: 5.minutes).perform_later
  end

  private

  def process_excel_updates
    require 'roo'
    
    updated_count = 0
    created_count = 0
    error_count = 0
    
    # Rails.logger.info "DEBUG: Inside process_excel_updates method."
    
    begin # Added begin block
      spreadsheet = Roo::Spreadsheet.open('merged.xlsx')
      # Rails.logger.info "DEBUG: Spreadsheet opened. Default sheet: #{spreadsheet.default_sheet}"
      spreadsheet.default_sheet = "opro - Sheet"
      # Rails.logger.info "DEBUG: Switched to sheet: #{spreadsheet.default_sheet}"
      
      Rails.logger.info "📊 [SyncExcelDataJob] Procesando #{spreadsheet.last_row - 1} filas del Excel"
      
      # Obtener warehouse por defecto
      warehouse = Warehouse.first || create_default_warehouse
      # Rails.logger.info "DEBUG: Warehouse: #{warehouse.name}"
      
      # Cargar todas las órdenes existentes en memoria para evitar N+1 queries
      existing_orders = ProductionOrder.all.index_by(&:no_opro)
      Rails.logger.info "📊 [SyncExcelDataJob] Cargadas #{existing_orders.count} órdenes existentes en memoria"
      
      # Procesar cada fila (empezando desde la fila 2, saltando header)
      (2..spreadsheet.last_row).each do |row_num|
        # Rails.logger.info "DEBUG: Processing row #{row_num}"
        begin
          row_data = spreadsheet.row(row_num)
          
          # Extraer datos clave
          no_opro = row_data[0]&.to_s&.strip
          cve_prop = row_data[3]&.to_s&.strip
          
          # Rails.logger.info "DEBUG: Row #{row_num} - no_opro: #{no_opro}, cve_prop: #{cve_prop}"
          
          next if no_opro.blank? || cve_prop.blank?
          
          # Buscar orden existente en el hash cargado en memoria
          existing_order = existing_orders[no_opro]
          
          if existing_order
            # Actualizar datos existentes
            if update_existing_order(existing_order, row_data)
              updated_count += 1
            end
          else
            # Crear nueva orden
            if create_new_order(row_data, warehouse)
              created_count += 1
            else
              error_count += 1
            end
          end
          
        rescue => e
          Rails.logger.error "❌ [SyncExcelDataJob] Error procesando fila #{row_num}: #{e.message}"
          error_count += 1
        end
      end
      
      # Rails.logger.info "DEBUG: Finished processing rows."
      
      {
        updated: updated_count,
        created: created_count,
        errors: error_count
      }
    rescue => e # Added rescue block for the entire method
      Rails.logger.error "❌ [SyncExcelDataJob] Error general en process_excel_updates: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      {
        updated: 0,
        created: 0,
        errors: 1 # Indicate a general error
      }
    end # Added end for begin block
  end

  def update_existing_order(order, row_data)
    # Actualizar campos que pueden cambiar
    updates = {}
    
    # Actualizar estado si cambió
    new_status = map_status(row_data[8])
    if order.status != new_status
      updates[:status] = new_status
      Rails.logger.info "🔄 [SyncExcelDataJob] Orden #{order.no_opro}: estado #{order.status} → #{new_status}"
    end
    
    # Actualizar cantidad si cambió
    new_quantity = parse_quantity(row_data[4])
    if order.quantity_requested != new_quantity
      updates[:quantity_requested] = new_quantity
      Rails.logger.info "🔄 [SyncExcelDataJob] Orden #{order.no_opro}: cantidad #{order.quantity_requested} → #{new_quantity}"
    end
    
    # Actualizar carga si cambió
    new_carga = row_data[5]&.to_f
    if new_carga && order.carga_copr != new_carga
      updates[:carga_copr] = new_carga
    end
    
    # Aplicar actualizaciones si hay cambios
    if updates.any?
      order.update!(updates)
      return true
    end
    
    false
  end

  def create_new_order(row_data, warehouse)
    # Extraer datos
    data = extract_row_data(row_data)
    
    # Buscar o crear producto
    product = find_or_create_product(data[:cve_prop])
    return false unless product
    
    # Crear orden de producción
    production_order = ProductionOrder.create!(
      warehouse: warehouse,
      product: product,
      quantity_requested: parse_quantity(data[:ren_opro]),
      status: map_status(data[:stat_opro]),
      priority: "medium",
      estimated_completion: parse_date(data[:fec_opro]),
      notes: data[:observa],
      lote_referencia: data[:lote],
      no_opro: data[:no_opro],
      carga_copr: data[:carga_opro],
      ano: data[:ano],
      mes: data[:mes],
      fecha_completa: parse_date(data[:fec_opro])
    )
    
    # Crear packing record asociado
    create_packing_record(production_order, data)
    
    # Crear notificaciones para admins y operadores
    create_production_order_notifications(production_order)
    
    Rails.logger.info "✨ [SyncExcelDataJob] Nueva orden creada: #{production_order.no_opro}"
    true
    
  rescue => e
    Rails.logger.error "❌ [SyncExcelDataJob] Error creando orden #{data[:no_opro]}: #{e.message}"
    false
  end

  def extract_row_data(row_data)
    {
      no_opro: row_data[0],
      cve_suc: row_data[1],
      fec_opro: row_data[2],
      cve_prop: row_data[3],
      ren_opro: row_data[4],
      carga_opro: row_data[5],
      stat_opro: row_data[8],
      lote: row_data[17],
      referencia: row_data[19],
      observa: row_data[25],
      mes: row_data[13],
      ano: row_data[14]
    }
  end

  def find_or_create_product(cve_prop)
    product = Product.find_by(name: cve_prop)
    return product if product
    
    category = Category.first || create_default_category
    micras, ancho_mm = parse_cve_prop_dimensions(cve_prop)
    
    Product.create!(
      name: cve_prop,
      description: generate_product_description(cve_prop, micras, ancho_mm),
      category: category,
      sku: generate_sku(cve_prop),
      active: true,
      price: 0.0,
      unit_of_measure: "KILO",
      reorder_point: 0,
      max_stock_level: 1000,
      batch_tracking: false
    )
  rescue => e
    Rails.logger.error "❌ [SyncExcelDataJob] Error creando producto #{cve_prop}: #{e.message}"
    nil
  end

  def create_packing_record(production_order, data)
    PackingRecord.create!(
      production_order: production_order,
      lote_padre: data[:lote],
      lote: data[:lote] || "#{data[:no_opro]}-001",
      cve_prod: data[:cve_prop],
      peso_bruto: 0.0,
      peso_neto: 0.0,
      metros_lineales: 0.0,
      consecutivo: 1,
      nombre: data[:cve_prop]
    )
  end

  # Métodos auxiliares (copiados del script original)
  def parse_cve_prop_dimensions(cve_prop)
    return [nil, nil] if cve_prop.blank?
    
    match = cve_prop.match(/(\d+)\s*\/\s*(\d+)/)
    if match
      [match[1].to_i, match[2].to_i]
    else
      [nil, nil]
    end
  end

  def generate_product_description(cve_prop, micras, ancho_mm)
    desc = "BOPP Transparente"
    desc += " #{micras} micras" if micras
    desc += " #{ancho_mm}mm ancho" if ancho_mm
    desc += " - #{cve_prop}"
    desc
  end

  def generate_sku(cve_prop)
    cve_prop.to_s.gsub(/[^A-Z0-9]/, '')[0..20]
  end

  def parse_quantity(ren_opro)
    return 0 if ren_opro.blank?
    ren_opro.to_i
  end

  def map_status(stat_opro)
    case stat_opro&.to_s&.downcase&.strip
    when "terminada", "completed", "finalizada"
      "completed"
    when "cancelada", "cancelled", "anulada"
      "cancelled"
    when "en proceso", "in_progress", "proceso"
      "in_progress"
    when "pausada", "paused"
      "paused"
    when "programada", "scheduled"
      "scheduled"
    else
      "pending"
    end
  end

  def parse_date(date_value)
    return nil if date_value.blank?
    
    case date_value
    when Date
      date_value
    when String
      Date.parse(date_value) rescue nil
    when Numeric
      Date.new(1900, 1, 1) + date_value.to_i rescue nil
    else
      nil
    end
  end

  def create_default_warehouse
    Warehouse.create!(
      name: "Almacén Principal",
      code: "MAIN",
      address: "Dirección principal"
    )
  end

  def create_default_category
    Category.create!(
      name: "Productos BOPP",
      description: "Productos de polipropileno biorientado"
    )
  end

  def create_production_order_notifications(production_order)
    # Crear notificaciones para todos los admins
    Admin.find_each do |admin|
      admin_user = find_or_create_admin_user(admin)
      if admin_user
        Notification.create_production_order_notification(
          user: admin_user,
          production_order: production_order
        )
      end
    end
    
    # También crear notificaciones para usuarios con permisos de operador si existen
    if defined?(User)
      User.where(role: ['supervisor', 'operador']).find_each do |user|
        Notification.create_production_order_notification(
          user: user,
          production_order: production_order
        )
      end
    end
  end

  def broadcast_sync_notification(result)
    return if result[:created] == 0 && result[:updated] == 0
    
    # Crear notificaciones persistentes para admins
    Admin.find_each do |admin|
      admin_user = find_or_create_admin_user(admin)
      if admin_user
        Notification.create!(
          user: admin_user,
          notification_type: "system",
          title: "📊 Datos sincronizados",
          message: "Excel actualizado: #{result[:created]} nuevas órdenes, #{result[:updated]} actualizadas",
          action_url: "/admin/production_orders",
          data: {
            sync_result: result,
            sync_time: Time.current.iso8601
          }
        )
      end
    end
    
    # También notificar a supervisores si existen
    if defined?(User)
      User.where(role: ['supervisor']).find_each do |user|
        Notification.create!(
          user: user,
          notification_type: "system",
          title: "📊 Datos sincronizados",
          message: "Excel actualizado: #{result[:created]} nuevas órdenes, #{result[:updated]} actualizadas",
          action_url: "/admin/production_orders",
          data: {
            sync_result: result,
            sync_time: Time.current.iso8601
          }
        )
      end
    end
  end

  def notify_sync_error(error)
    # Crear notificaciones de error solo para administradores
    Admin.find_each do |admin|
      admin_user = find_or_create_admin_user(admin)
      if admin_user
        Notification.create!(
          user: admin_user,
          notification_type: "admin_alert",
          title: "❌ Error en sincronización",
          message: "Error procesando merged.xlsx: #{error.message[0..100]}",
          action_url: "/admin/production_orders",
          data: {
            error_message: error.message,
            error_time: Time.current.iso8601,
            error_class: error.class.name
          }
        )
      end
    end
  end

  def find_or_create_admin_user(admin)
    # Buscar usuario admin existente por email
    user = User.find_by(email: admin.email, role: 'admin')
    
    # Si no existe, crear uno nuevo
    unless user
      user = User.create!(
        email: admin.email,
        name: admin.name || admin.email,
        role: 'admin',
        password: SecureRandom.hex(16), # Password temporal aleatorio
        active: true
      )
    end
    
    user
  rescue => e
    Rails.logger.error "❌ [SyncExcelDataJob] Error creando usuario admin para #{admin.email}: #{e.message}"
    nil
  end
end