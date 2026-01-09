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

  def print_selected_labels
    selected_ids = JSON.parse(request.body.read)['selected_ids'] || []
    inventory_codes = InventoryCode.where(id: selected_ids)
    company = current_admin&.company || current_user&.company
    print_success = true

    if company&.serial_service_url_configured? && SerialCommunicationService.health_check(company: company)
      Rails.logger.info "Serial server is accessible, proceeding with printing for #{inventory_codes.count} labels."
      
      inventory_codes.each do |code|
        label_content = generate_tspl2_for_inventory_code(code.label_data)
        result = SerialCommunicationService.print_label(
          label_content,
          ancho_mm: 80,
          alto_mm: 50,
          company: company
        )
        unless result
          print_success = false
          Rails.logger.error "Failed to print label for InventoryCode ID: #{code.id}"
        end
      end
    else
      Rails.logger.warn "Printer not configured or serial service not accessible."
      print_success = false
    end

    if print_success
      message = "#{inventory_codes.count} etiquetas enviadas a la impresora."
    else
      message = "Hubo un problema al enviar las etiquetas a la impresora. Verifique la configuración y el servicio de serie."
    end
    
    render json: {
      status: print_success ? 'success' : 'error',
      print_success: print_success,
      message: message,
      count: inventory_codes.count
    }
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

  def generate_tspl2_for_inventory_code(data)
    tspl = [
      "SIZE 80 mm, 50 mm",
      "GAP 2 mm, 0 mm",
      "DIRECTION 1,0",
      "CLS",
      "TEXT 150,20,\"3\",0,1,1,\"Orden: #{data[:no_ordp]}\"",
      "TEXT 150,60,\"3\",0,1,1,\"Lote: #{data[:lote]}\"",
      "TEXT 150,100,\"2\",0,1,1,\"Prod: #{data[:cve_prod]}\"",
      "TEXT 150,140,\"2\",0,1,1,\"Comp: #{data[:cve_copr]}\"",
      "TEXT 150,180,\"3\",0,1,1,\"Cant: #{data[:can_copr]} KG\"",
      "TEXT 150,220,\"2\",0,1,1,\"Fecha: #{data[:fech_cto]}\"",
      "BARCODE 150,260,\"128\",40,1,0,2,2,\"#{data[:lote]}\"",
      "PRINT 1,1"
    ]
    tspl.join("\n") + "\n"
  end
end