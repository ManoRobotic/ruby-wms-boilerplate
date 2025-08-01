class Admin::WarehousesController < AdminController
  include StandardCrudResponses
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
    @warehouse = Warehouse.new(active: true)
  end

  def create
    @warehouse = Warehouse.new(warehouse_params)
    
    # Ensure active is set if not provided
    @warehouse.active = true if @warehouse.active.nil?

    respond_to do |format|
      if @warehouse.save
        format.html { redirect_to admin_warehouses_path, notice: "Almacén creado exitosamente." }
        format.json { render :show, status: :created, location: [:admin, @warehouse] }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @warehouse.errors, status: :unprocessable_entity }
      end
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
      redirect_to admin_warehouses_path, alert: "No se puede eliminar un almacén que tiene zonas asociadas."
    elsif @warehouse.orders.any?
      redirect_to admin_warehouses_path, alert: "No se puede eliminar un almacén que tiene órdenes asociadas."
    else
      @warehouse.destroy
      redirect_to admin_warehouses_path, notice: "Almacén eliminado exitosamente."
    end
  end

  private

  def set_warehouse
    @warehouse = Warehouse.find(params[:id])
  end

  def warehouse_params
    params.require(:warehouse).permit(:name, :code, :address, :active, :contact_info)
  end
end
