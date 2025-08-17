# Inicializar jobs recurrentes al arrancar Rails
Rails.application.config.after_initialize do
  # Solo ejecutar en desarrollo y producción, no en tests
  unless Rails.env.test?
    Rails.logger.info "🚀 Iniciando jobs recurrentes..."
    
    # Programar el primer SyncExcelDataJob
    SyncExcelDataJob.set(wait: 10.seconds).perform_later
    
    # Programar el primer UpdateProductionMetricsJob  
    UpdateProductionMetricsJob.set(wait: 30.seconds).perform_later
    
    Rails.logger.info "✅ Jobs recurrentes programados"
  end
end