class Admin::InventoryCodesController < AdminController
  before_action :authorize_inventory_codes_access!
  before_action :set_inventory_code, only: [:show, :edit, :update, :destroy]

  def index
    # Build base query with filters
    base_query = InventoryCode.all

    # Search
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      base_query = base_query.where(
        "no_ordp ILIKE ? OR cve_prod ILIKE ? OR cve_copr ILIKE ? OR lote ILIKE ?",
        search_term, search_term, search_term, search_term
      )
    end

    # Date range
    base_query = base_query.by_date_range(params[:start_date], params[:end_date])

    # Statistics (calculated before pagination)
    @total_count = base_query.count
    @active_count = base_query.where(tip_copr: 1).count
    @inactive_count = base_query.where(tip_copr: 0).count
    @unique_products_count = base_query.distinct.count(:cve_prod)

    # Pagination
    @inventory_codes = base_query.order(sort_column + " " + sort_direction).page(params[:page]).per(20)
  end

  def selected_data
    # Handle both GET (using session) and POST (using provided IDs) requests
    if request.post?
      request_body = JSON.parse(request.body.read)
      selected_ids = request_body['selected_ids'] || []
    else
      selected_ids = get_selected_codes
    end
    
    @inventory_codes = InventoryCode.where(id: selected_ids)
    
    codes_data = @inventory_codes.map do |code|
      {
        id: code.id,
        no_ordp: code.no_ordp,
        cve_prod: code.cve_prod,
        cve_copr: code.cve_copr,
        can_copr: code.can_copr,
        formatted_quantity: code.formatted_quantity,
        costo: code.costo,
        formatted_cost: code.formatted_cost,
        lote: code.lote,
        fech_cto: code.fech_cto,
        status_display: code.status_display,
        tip_copr: code.tip_copr
      }
    end
    
    render json: {
      status: 'success',
      data: codes_data,
      count: codes_data.length,
      message: "#{codes_data.length} códigos seleccionados"
    }
  end

  def toggle_selection
    begin
      request_body = JSON.parse(request.body.read)
      code_id = request_body['code_id']
      
      if code_id.blank?
        render json: {
          status: 'error',
          message: 'Code ID is required'
        }, status: 422
        return
      end
      
      # Get current selections from session
      selected_codes = get_selected_codes.map(&:to_s)
      code_id_str = code_id.to_s
      
      if selected_codes.include?(code_id_str)
        selected_codes.delete(code_id_str)
        selected = false
      else
        selected_codes.push(code_id_str)
        selected = true
      end

      # Save back to session
      set_selected_codes(selected_codes)

      render json: {
        status: 'success',
        selected: selected,
        selected_count: selected_codes.count
      }
    rescue JSON::ParserError => e
      Rails.logger.error "JSON Parse Error in toggle_selection: #{e.message}"
      render json: {
        status: 'error',
        message: 'Invalid JSON format'
      }, status: 422
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Code not found in toggle_selection: #{e.message}"
      render json: {
        status: 'error',
        message: 'Code not found'
      }, status: 404
    rescue StandardError => e
      Rails.logger.error "Error in toggle_selection: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: {
        status: 'error',
        message: 'Internal server error'
      }, status: 500
    end
  end

  def clear_selection
    previous_count = get_selected_codes.count
    
    # Clear session
    session[:selected_inventory_codes] = nil
    
    render json: {
      status: 'success',
      message: "Se eliminaron #{previous_count} códigos de la selección",
      previous_count: previous_count,
      selected_count: 0
    }
  end

  def show
  end

  def new
    @inventory_code = InventoryCode.new
  end

  def edit
  end

  def create
    @inventory_code = InventoryCode.new(inventory_code_params)

    if @inventory_code.save
      redirect_to admin_inventory_codes_path, notice: 'Código de inventario creado exitosamente.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @inventory_code.update(inventory_code_params)
      redirect_to admin_inventory_code_path(@inventory_code), notice: 'Código de inventario actualizado exitosamente.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @inventory_code.destroy
    redirect_to admin_inventory_codes_path, notice: 'Código de inventario eliminado exitosamente.'
  end

  def import_excel
    begin
      # Run the import task
      Rake::Task['inventory:import_visible_data'].invoke
      redirect_to admin_inventory_codes_path, notice: 'Datos importados exitosamente desde archivo DBF.'
    rescue => e
      redirect_to admin_inventory_codes_path, alert: "Error al importar datos: #{e.message}"
    end
  end

  def export_excel
    # Placeholder for future Excel export functionality
    redirect_to admin_inventory_codes_path, notice: 'Funcionalidad de exportación de Excel pendiente.'
  end

  private

  def sortable_columns
    %w[no_ordp cve_prod cve_copr can_copr costo lote fech_cto tip_copr]
  end

  def authorize_inventory_codes_access!
    unless current_user&.can?("read_inventory_codes") || current_admin
      redirect_to admin_root_path, alert: "No tienes permisos para acceder a los códigos de inventario."
    end
  end

  def set_inventory_code
    @inventory_code = InventoryCode.find(params[:id])
  end

  def inventory_code_params
    params.require(:inventory_code).permit(
      :no_ordp, :cve_copr, :cve_prod, :can_copr, :tip_copr, :costo,
      :fech_cto, :cve_suc, :trans, :lote, :new_med, :new_copr,
      :costo_rep, :partresp, :dmov, :partop, :fcdres, :undres
    )
  end

  def get_selected_codes
    session[:selected_inventory_codes] || []
  end

  def set_selected_codes(codes)
    session[:selected_inventory_codes] = codes
  end

  def selected_data
    # Handle both GET (using session) and POST (using provided IDs) requests
    if request.post?
      request_body = JSON.parse(request.body.read)
      selected_ids = request_body['selected_ids'] || []
    else
      selected_ids = get_selected_codes
    end

    @inventory_codes = InventoryCode.where(id: selected_ids)

    codes_data = @inventory_codes.map do |code|
      {
        id: code.id,
        no_ordp: code.no_ordp,
        cve_prod: code.cve_prod,
        cve_copr: code.cve_copr,
        can_copr: code.can_copr,
        formatted_quantity: code.formatted_quantity,
        costo: code.costo,
        formatted_cost: code.formatted_cost,
        lote: code.lote,
        fech_cto: code.fech_cto,
        status_display: code.status_display,
        tip_copr: code.tip_copr
      }
    end

    render json: {
      status: 'success',
      data: codes_data,
      count: codes_data.length,
      message: "#{codes_data.length} códigos seleccionados"
    }
  end

  def print_selected_labels
    # Handle POST request with selected IDs
    request_body = JSON.parse(request.body.read)
    selected_ids = request_body['selected_ids'] || []

    @inventory_codes = InventoryCode.where(id: selected_ids)

    codes_data = @inventory_codes.map do |code|
      {
        no_ordp: code.no_ordp,
        cve_prod: code.cve_prod,
        cve_copr: code.cve_copr,
        can_copr: code.can_copr,
        formatted_quantity: code.formatted_quantity,
        lote: code.lote,
        fech_cto: code.fech_cto&.strftime("%d/%m/%Y"),
        status: code.status_display,
        tip_copr: code.tip_copr
      }
    end

    # Intentar imprimir las etiquetas físicamente si hay una impresora configurada
    print_success = true
    
    Rails.logger.info "Checking if printer is configured for current admin: #{current_admin&.printer_configured?}"
    Rails.logger.info "Checking if printer is configured for current user: #{current_user&.printer_configured?}"
    
    if current_admin&.printer_configured?
      Rails.logger.info "Printer is configured for admin, proceeding with printing"
      codes_data.each do |data|
        # Crear contenido de la etiqueta en formato TSPL2 para la impresora
        label_content = generate_inventory_code_tspl2_label_content(data)
        Rails.logger.info "Generated label content: #{label_content}"

        # Enviar a la impresora
        result = SerialCommunicationService.print_label(
          label_content,
          ancho_mm: 80,  # Configurable según el tamaño de la etiqueta
          alto_mm: 50,
          company: current_admin.company
        )
        Rails.logger.info "Print result: #{result}"
        print_success = print_success && result
      end
    elsif current_user&.printer_configured?
      Rails.logger.info "Printer is configured for user, proceeding with printing"
      codes_data.each do |data|
        # Crear contenido de la etiqueta en formato TSPL2 para la impresora
        label_content = generate_inventory_code_tspl2_label_content(data)
        Rails.logger.info "Generated label content: #{label_content}"

        # Enviar a la impresora
        result = SerialCommunicationService.print_label(
          label_content,
          ancho_mm: 80,  # Configurable según el tamaño de la etiqueta
          alto_mm: 50,
          company: current_user.company
        )
        Rails.logger.info "Print result: #{result}"
        print_success = print_success && result
      end
    else
      Rails.logger.info "Printer not configured for current user/admin"
    end

    render json: {
      status: 'success',
      print_success: print_success,
      message: print_success ? "#{codes_data.length} etiquetas enviadas a imprimir." : "#{codes_data.length} códigos procesados pero hubo un problema al enviar a la impresora.",
      data: codes_data,
      count: codes_data.length
    }
  end

  private

  # Generate TSPL2 label content for inventory codes
  def generate_inventory_code_tspl2_label_content(label_data)
    # Prepare label content in TSPL2 format for inventory codes
    tspl2_commands = [
      "SIZE 80 mm, 50 mm",     # Tamaño de la etiqueta
      "GAP 2 mm, 0 mm",        # Espacio entre etiquetas
      "DIRECTION 1,0",         # Dirección
      "REFERENCE 0,0",         # Punto de referencia
      "SET TEAR ON",           # Modo tear
      "CLS"                    # Limpiar buffer
    ]

    # Add content - adjust positioning as needed
    tspl2_commands << "TEXT 160,75,\"4\",0,1,1,\"#{label_data[:no_ordp] || 'N/A'}\""
    tspl2_commands << "TEXT 160,150,\"3\",0,1,1,\"Prod: #{label_data[:cve_prod] || 'N/A'}\""
    tspl2_commands << "TEXT 160,225,\"3\",0,1,1,\"Cve Copr: #{label_data[:cve_copr] || 'N/A'}\""
    tspl2_commands << "TEXT 160,300,\"3\",0,1,1,\"Cantidad: #{label_data[:can_copr] || 0}\""
    tspl2_commands << "TEXT 160,375,\"2\",0,1,1,\"Lote: #{label_data[:lote] || 'N/A'}\""
    tspl2_commands << "TEXT 160,450,\"2\",0,1,1,\"Fecha: #{label_data[:fech_cto] || 'N/A'}\""
    tspl2_commands << "TEXT 160,525,\"2\",0,1,1,\"Tipo: #{label_data[:tip_copr] || 'N/A'}\""

    # Print command
    tspl2_commands << "PRINT 1,1"

    # Join commands with newline characters
    tspl2_commands.join("\n") + "\n"
  end
end