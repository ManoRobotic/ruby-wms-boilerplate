class ProcessExcelJob < ApplicationJob
  queue_as :default
  
  def perform(file_path = nil)
    Rails.logger.info "Starting Excel processing job"
    
    begin
      service = ExcelProcessorService.new(file_path)
      results = service.process_merged_file
      
      Rails.logger.info "Excel processing completed successfully"
      Rails.logger.info "Created #{results[:production_orders].count} production orders"
      Rails.logger.info "Created #{results[:packing_records].count} packing records"
      
      # Create notification for admin users
      create_completion_notification(results)
      
      results
    rescue => e
      Rails.logger.error "Excel processing failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Create error notification
      create_error_notification(e)
      
      raise e
    end
  end
  
  private
  
  def create_completion_notification(results)
    # Create notification without user_id since Admin model might not have notifications
    Rails.logger.info "Excel processing completed successfully"
    Rails.logger.info "Created #{results[:production_orders].count} production orders"
    Rails.logger.info "Created #{results[:packing_records].count} packing records"
  end
  
  def create_error_notification(error)
    # Log error instead of creating notification
    Rails.logger.error "Excel processing failed: #{error.message}"
  end
end