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

    base_query = base_query.by_order_number(params[:no_ordp]) if params[:no_ordp].present?
    base_query = base_query.by_product_code(params[:cve_prod]) if params[:cve_prod].present?
    base_query = base_query.by_component_code(params[:cve_copr]) if params[:cve_copr].present?
    base_query = base_query.by_lote(params[:lote]) if params[:lote].present?
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
    selected_ids = get_selected_codes
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
end