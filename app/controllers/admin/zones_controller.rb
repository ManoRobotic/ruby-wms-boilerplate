class Admin::ZonesController < AdminController
  before_action :set_warehouse
  before_action :set_zone, only: [ :show, :edit, :update, :destroy, :locations ]
  before_action :authorize_zone_management!, except: [ :index, :show, :locations ]
  before_action :authorize_zone_read!, only: [ :index, :show, :locations ]
  before_action :check_warehouse_access!

  def index
    @zones = @warehouse.zones.includes(:locations)
                      .page(params[:page])
                      .per(20)

    @zones = @zones.by_type(params[:zone_type]) if params[:zone_type].present?
    @zones = @zones.search(params[:search]) if params[:search].present?

    @sections_data = @zones.map do |zone|
      total_locations = zone.locations.count
      occupied_locations = zone.locations.joins(:stocks).distinct.count
      usage_percentage = total_locations > 0 ? (occupied_locations * 100 / total_locations) : 0

      {
        id: zone.code,
        name: zone.name,
        date: zone.updated_at.strftime("%d/%m/%Y"),
        status: "Usada",
        usage: "#{usage_percentage}%",
        zone_id: zone.id,
        zone_type: zone.zone_type
      }
    end
  end

  def locations
    @zone = @warehouse.zones.find(params[:id])
    
    # Simplificar la consulta para evitar problemas con STRING_AGG
    @locations = @zone.locations
                    .includes(stocks: :product)
                    .order(:aisle, :bay, :level, :position)

    locations_data = @locations.map do |location|
      stocks_count = location.stocks.count
      product_names = location.stocks.includes(:product).map { |s| s.product&.name }.compact.join(', ')
      last_updated = location.stocks.maximum(:updated_at)
      
      {
        id: location.id,
        aisle: location.aisle,
        bay: location.bay,
        level: location.level,
        position: location.position,
        location_type: location.location_type,
        full_code: location.full_code,
        last_updated_formatted: last_updated&.strftime("%d/%m/%Y"),
        stocks_count: stocks_count,
        product_names: product_names,
        stocks: location.stocks.includes(:product).map do |stock|
          {
            id: stock.id,
            quantity: stock.quantity,
            product: {
              name: stock.product&.name,
              sku: stock.product&.sku
            }
          }
        end
      }
    end

    respond_to do |format|
      format.json { render json: locations_data }
      format.html { redirect_to admin_warehouse_zones_path(@warehouse) }
    end
  end

  def show
    @locations_count = @zone.locations.count
    @utilization = @zone.utilization_percentage
    @available_locations = @zone.available_locations.count
  end

  def new
    @zone = @warehouse.zones.build
  end

  def create
    @zone = @warehouse.zones.build(zone_params)

    if @zone.save
      redirect_to admin_warehouse_zone_path(@warehouse, @zone), notice: "Zone was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @zone.update(zone_params)
      redirect_to admin_warehouse_zone_path(@warehouse, @zone), notice: "Zone was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @zone.locations.any?
      redirect_to admin_warehouse_zones_path(@warehouse), alert: "No se puede eliminar la zona porque tiene ubicaciones activas."
    elsif @zone.cycle_counts.any?
      redirect_to admin_warehouse_zones_path(@warehouse), alert: "No se puede eliminar la zona porque tiene conteos cíclicos asociados."
    else
      begin
        @zone.destroy!
        redirect_to admin_warehouse_zones_path(@warehouse), notice: "Zona eliminada exitosamente."
      rescue => e
        Rails.logger.error "Failed to delete zone #{@zone.id}: #{e.message}"
        redirect_to admin_warehouse_zones_path(@warehouse), alert: "Error al eliminar la zona: #{e.message}"
      end
    end
  end

  private

  def set_warehouse
    @warehouse = Warehouse.find(params[:warehouse_id])
  end

  def set_zone
    @zone = @warehouse.zones.find(params[:id])
  end

  def zone_params
    params.require(:zone).permit(:name, :code, :zone_type, :description)
  end

  def authorize_zone_management!
    unless current_admin || current_user&.can?("create_zones")
      redirect_to admin_root_path, alert: "No tienes permisos para gestionar zonas."
    end
  end

  def authorize_zone_read!
    unless current_admin || current_user&.can?("read_zones")
      redirect_to admin_root_path, alert: "No tienes permisos para ver zonas."
    end
  end

  def check_warehouse_access!
    if current_user && current_user.warehouse_id.present?
      unless @warehouse.id == current_user.warehouse_id
        redirect_to admin_root_path, alert: "No tienes acceso a este almacén."
      end
    end
  end
end
