class Admin::ConfigurationsController < AdminController
  before_action :check_edit_permissions, only: [:edit, :update]

  def show
    @admin = current_admin || current_user
    # Use company configuration for display
  end

  def edit
    @admin = current_admin || current_user
    # Use company configuration for editing
  end

  def update
    @admin = current_admin || current_user
    
    # Update company configuration instead of admin configuration
    unless @admin.company
      @admin.errors.add(:base, "No se puede actualizar la configuración: el administrador no está asociado a una empresa.")
      render :edit, status: :unprocessable_entity
      return
    end
    
    if @admin.company.update(configurations_params)
      # Validar las credenciales si se proporcionaron
      if params[:admin][:google_credentials_json].present?
        begin
          credentials_hash = JSON.parse(params[:admin][:google_credentials_json])
          @admin.company.set_google_credentials(credentials_hash)
          
          unless @admin.company.validate_google_credentials
            @admin.company.errors.add(:google_credentials, "Las credenciales de Google no tienen el formato correcto")
            render :edit, status: :unprocessable_entity
            return
          end
          
          @admin.company.save!
          redirect_to admin_configurations_path, notice: "Configuración de Google Sheets actualizada exitosamente."
        rescue JSON::ParserError
          @admin.company.errors.add(:google_credentials, "El JSON de credenciales no es válido")
          render :edit, status: :unprocessable_entity
        rescue => e
          @admin.company.errors.add(:base, "Error al procesar las credenciales: #{e.message}")
          render :edit, status: :unprocessable_entity
        end
      else
        redirect_to admin_configurations_path, notice: "Configuración actualizada exitosamente."
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def test_connection
    @admin = current_admin
    
    unless @admin.google_sheets_configured?
      render json: { 
        success: false, 
        message: "Google Sheets no está configurado correctamente. Faltan datos de configuración." 
      }
      return
    end

    begin
      # Test usando el servicio que auto-detecta la hoja
      service = AdminGoogleSheetsService.new(@admin)
      worksheet = service.find_opro_worksheet
      
      if worksheet
        render json: { 
          success: true, 
          message: "Conexión exitosa. Hoja auto-detectada: '#{worksheet.title}' con #{worksheet.num_rows} filas.",
          worksheet_title: worksheet.title,
          num_rows: worksheet.num_rows,
          worksheet_gid: worksheet.gid
        }
      else
        render json: { 
          success: false, 
          message: "No se encontró ninguna hoja con datos de OPRO. Verifique que tenga columnas como 'no_opro', 'fec_opro', etc." 
        }
      end
    rescue => e
      Rails.logger.error "Error en test de conexión Google Sheets para #{@admin.email}: #{e.message}"
      render json: { 
        success: false, 
        message: "Error de conexión: #{e.message}" 
      }
    end
  end

  def check_changes
    @admin = current_admin
    
    unless @admin.google_sheets_configured?
      render json: { 
        success: false, 
        message: "Google Sheets no está configurado correctamente." 
      }
      return
    end

    begin
      service = AdminGoogleSheetsService.new(@admin)
      result = service.check_for_changes
      
      render json: { 
        success: true, 
        has_changes: result[:has_changes],
        message: result[:message],
        details: result[:details],
        current_rows: result[:current_rows],
        last_sync: result[:last_sync]&.strftime('%d/%m/%Y %H:%M')
      }
    rescue => e
      Rails.logger.error "Error verificando cambios para #{@admin.email}: #{e.message}"
      render json: { 
        success: false, 
        message: "Error verificando cambios: #{e.message}" 
      }
    end
  end

  def incremental_sync
    @admin = current_admin
    
    unless @admin.google_sheets_configured?
      redirect_to admin_configurations_path, 
                  alert: "Google Sheets no está configurado correctamente."
      return
    end

    begin
      service = IncrementalGoogleSheetsService.new(@admin)
      result = service.incremental_sync_production_orders
      
      if result[:success]
        redirect_to admin_configurations_path, 
                    notice: "#{result[:message]}. #{result[:errors].any? ? "Errores: #{result[:errors].count}" : ""}"
      else
        redirect_to admin_configurations_path, 
                    alert: "Error en la sincronización incremental: #{result[:message]}"
      end
    rescue => e
      Rails.logger.error "Error en sincronización incremental para #{@admin.email}: #{e.message}"
      redirect_to admin_configurations_path, 
                  alert: "Error inesperado durante la sincronización incremental."
    end
  end

  def sync_now
    @admin = current_admin
    
    unless @admin.google_sheets_configured?
      redirect_to admin_configurations_path, 
                  alert: "Google Sheets no está configurado correctamente."
      return
    end

    force_sync = params[:force] == 'true'

    begin
      service = AdminGoogleSheetsService.new(@admin)
      
      # Primero verificar si hay cambios
      unless force_sync
        change_check = service.check_for_changes
        unless change_check[:has_changes]
          redirect_to admin_configurations_path, 
                      notice: "Sin cambios detectados. #{change_check[:details]}. Última sincronización: #{@admin.last_sync_at&.strftime('%d/%m/%Y %H:%M')}"
          return
        end
      end
      
      result = service.sync_production_orders(force_sync: force_sync)
      
      if result[:success]
        if result[:skipped]
          redirect_to admin_configurations_path, notice: result[:message]
        else
          redirect_to admin_configurations_path, 
                      notice: "#{result[:message]}. #{result[:errors].any? ? "Errores: #{result[:errors].count}" : ""}"
        end
      else
        redirect_to admin_configurations_path, 
                    alert: "Error en la sincronización: #{result[:message]}"
      end
    rescue => e
      Rails.logger.error "Error en sincronización manual para #{@admin.email}: #{e.message}"
      redirect_to admin_configurations_path, 
                  alert: "Error inesperado durante la sincronización."
    end
  end

  # Endpoint para guardar configuración automáticamente
  def auto_save
    @admin = current_admin
    
    unless @admin.company
      render json: { success: false, message: "No se puede actualizar la configuración: el administrador no está asociado a una empresa." }, status: :unprocessable_entity
      return
    end
    
    # Handle both formats: direct parameters and nested under company
    params_to_update = if params[:company].present?
                        params.require(:company).permit(:serial_port, :printer_port, :serial_baud_rate, :printer_baud_rate, :serial_parity, :printer_parity, :serial_stop_bits, :printer_stop_bits, :serial_data_bits, :printer_data_bits, :auto_save_consecutivo)
                      else
                        params.permit(:serial_port, :printer_port, :serial_baud_rate, :printer_baud_rate, :serial_parity, :printer_parity, :serial_stop_bits, :printer_stop_bits, :serial_data_bits, :printer_data_bits, :auto_save_consecutivo)
                      end
    
    # Solo actualizar los campos que se envían
    if @admin.company.update(params_to_update)
      respond_to do |format|
        format.html { redirect_back(fallback_location: admin_configurations_path, notice: "Configuración guardada automáticamente.") }
        format.json { render json: { success: true, message: "Configuración guardada automáticamente." } }
      end
    else
      respond_to do |format|
        format.html { redirect_back(fallback_location: admin_configurations_path, alert: "Error al guardar la configuración.") }
        format.json { render json: { success: false, message: "Error al guardar la configuración.", errors: @admin.company.errors }, status: :unprocessable_entity }
      end
    end
  end

  private

  def check_edit_permissions
    if current_user&.operador?
      redirect_to admin_configurations_path, alert: "No tienes permisos para editar la configuración."
    end
  end

  def configurations_params
    params.require(:admin).permit(:google_sheets_enabled, :sheet_id, :serial_port, :serial_baud_rate, :serial_parity, :serial_stop_bits, :serial_data_bits, :printer_port, :printer_baud_rate, :printer_parity, :printer_stop_bits, :printer_data_bits)
    # Ya no requerimos worksheet_gid porque se auto-detecta
  end
end