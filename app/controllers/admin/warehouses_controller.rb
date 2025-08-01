class Admin::WarehousesController < AdminController
  before_action :set_warehouse, only: [ :show, :edit, :update, :destroy ]

  def index
    @warehouses = Warehouse.includes(:zones)
                          .page(params[:page])
                          .per(20)

    @warehouses = @warehouses.search(params[:search]) if params[:search].present?
    @warehouses = @warehouses.where(active: params[:active]) if params[:active].present?
  end

  def show
    @zones_count = @warehouse.zones.count
    @locations_count = @warehouse.locations.count
    @active_tasks = @warehouse.tasks.active.count
    @pending_pick_lists = @warehouse.pick_lists.pending.count
    @utilization = @warehouse.utilization_percentage
  end

  def new
    @warehouse = Warehouse.new
  end

  def create
    @warehouse = Warehouse.new(warehouse_params)

    if @warehouse.save
      redirect_to admin_warehouses_path, notice: "Almacén creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @warehouse.update(warehouse_params)
      redirect_to admin_warehouse_path(@warehouse), notice: "Almacén actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @warehouse.zones.any?
      redirect_to admin_warehouses_path, alert: "Cannot delete warehouse with existing zones."
    else
      @warehouse.destroy
      redirect_to admin_warehouses_path, notice: "Warehouse was successfully deleted."
    end
  end

  private

  def set_warehouse
    @warehouse = Warehouse.find(params[:id])
  end

  def warehouse_params
    params.require(:warehouse).permit(:name, :code, :address, :active, contact_info: {})
  end
end
