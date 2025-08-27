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
    @inventory_codes = base_query.order(created_at: :desc).page(params[:page]).per(20)
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
end