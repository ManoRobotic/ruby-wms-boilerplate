class UpdateProductionMetricsJob < ApplicationJob
  queue_as :default

  # Job para actualizar métricas de producción automáticamente
  # Se puede ejecutar cada 5-15 minutos para mantener datos actualizados
  
  def perform
    Rails.logger.info "🔄 Starting production metrics update..."
    
    # Actualizar órdenes en progreso o completadas recientes
    orders_to_update = ProductionOrder.where(
      status: ['in_progress', 'completed']
    ).where(
      updated_at: 1.hour.ago..Time.current
    ).includes(:packing_records)
    
    updated_count = 0
    
    orders_to_update.find_each do |order|
      begin
        # Simular obtención de datos desde sistemas externos
        # En producción real, esto vendría de:
        # - APIs de básculas
        # - Sistemas de control de producción  
        # - Sensores IoT
        # - Bases de datos de maquinaria
        
        update_order_metrics(order)
        updated_count += 1
        
      rescue => e
        Rails.logger.error "❌ Error updating order #{order.order_number}: #{e.message}"
      end
    end
    
    Rails.logger.info "✅ Production metrics update completed. #{updated_count} orders updated."
    
    # Enviar notificación si hubo cambios significativos
    if updated_count > 0
      broadcast_metrics_update(updated_count)
    end
    
    # Programar el próximo job en 5 minutos
    UpdateProductionMetricsJob.set(wait: 5.minutes).perform_later
  end

  private

  def update_order_metrics(order)
    order.packing_records.each do |packing|
      # Solo actualizar si no tiene datos reales aún
      next if packing.peso_neto > 0 && packing.metros_lineales > 0
      
      # En producción real, aquí harías:
      # - Consultas a APIs externas
      # - Lecturas de sensores
      # - Integración con sistemas ERP
      
      # Ejemplo de actualización simulada:
      if order.status == 'completed'
        # Para órdenes completadas, generar datos finales
        update_completed_order_data(packing)
      elsif order.status == 'in_progress'
        # Para órdenes en progreso, datos parciales
        update_partial_order_data(packing)
      end
    end
  end

  def update_completed_order_data(packing)
    # Simular datos finales de producción completada
    estimated_production = calculate_estimated_production(packing.cve_prod)
    
    packing.update!(
      metros_lineales: estimated_production[:metros],
      peso_bruto: estimated_production[:peso_bruto],
      peso_neto: estimated_production[:peso_neto]
    )
    
    Rails.logger.info "📊 Updated completed order: #{packing.lote} - #{estimated_production[:metros]}m, #{estimated_production[:peso_neto]}kg"
  end

  def update_partial_order_data(packing)
    # Simular datos parciales para órdenes en progreso
    progress_percentage = rand(0.2..0.8) # 20-80% de progreso
    estimated_production = calculate_estimated_production(packing.cve_prod)
    
    packing.update!(
      metros_lineales: (estimated_production[:metros] * progress_percentage).round(1),
      peso_bruto: (estimated_production[:peso_bruto] * progress_percentage).round(1),
      peso_neto: (estimated_production[:peso_neto] * progress_percentage).round(1)
    )
    
    Rails.logger.info "🔄 Updated in-progress order: #{packing.lote} - #{(progress_percentage*100).round}% complete"
  end

  def calculate_estimated_production(cve_prod)
    # Calcular producción estimada basada en CVE_PROD
    # En la realidad, esto vendría de especificaciones técnicas
    
    # Extraer dimensiones del CVE_PROD
    match = cve_prod.match(/(\d+)\s*\/\s*(\d+)/)
    if match
      micras = match[1].to_i
      ancho_mm = match[2].to_i
      
      # Fórmulas de ejemplo (en producción serían fórmulas reales)
      metros_base = rand(500..2000) # Base de metros
      factor_ancho = ancho_mm / 100.0 # Factor por ancho
      factor_micras = micras / 30.0 # Factor por grosor
      
      metros = (metros_base * factor_ancho).round(1)
      peso_bruto = (metros * factor_micras * 0.3).round(2) # Densidad estimada
      peso_neto = (peso_bruto * 0.85).round(2) # 85% del peso bruto
      
      {
        metros: metros,
        peso_bruto: peso_bruto,
        peso_neto: peso_neto
      }
    else
      # Valores por defecto si no se puede parsear
      {
        metros: rand(300..1500).to_f,
        peso_bruto: rand(50..400).to_f,
        peso_neto: rand(40..340).to_f
      }
    end
  end

  def broadcast_metrics_update(updated_count)
    # Enviar notificación en tiempo real a usuarios conectados
    notification_data = {
      title: "Métricas actualizadas",
      message: "Se actualizaron #{updated_count} órdenes de producción",
      type: "info",
      timestamp: Time.current.iso8601
    }

    # Broadcast a usuarios con permisos
    User.where(role: ['admin', 'supervisor', 'operador']).find_each do |user|
      ActionCable.server.broadcast(
        "notifications_#{user.id}",
        {
          type: 'metrics_update',
          notification: notification_data
        }
      )
    end
  end
end