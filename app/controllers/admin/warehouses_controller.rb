class Admin::WarehousesController < AdminController
  include StandardCrudResponses
  before_action :set_warehouse, only: [ :show, :edit, :update, :destroy ]
  before_action :authorize_warehouse_management!, except: [ :index, :show ]
  before_action :authorize_warehouse_read!, only: [ :index, :show ]

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
        format.json { render :show, status: :created, location: [ :admin, @warehouse ] }
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
    # Check all possible dependencies - only count ACTIVE ones
    zones_count = @warehouse.zones.count
    
    # Only count orders that are not cancelled or delivered (check both status fields)
    active_orders_count = @warehouse.orders.where.not(status: ['cancelled', 'delivered'])
                                            .where.not(fulfillment_status: ['cancelled', 'delivered']).count
    
    # Only count active tasks
    active_tasks_count = @warehouse.tasks.where.not(status: ['completed', 'cancelled']).count rescue 0
    
    # Only count active pick lists
    active_pick_lists_count = @warehouse.pick_lists.where(status: ['pending', 'assigned', 'in_progress']).count
    
    # Only count active waves
    active_waves_count = @warehouse.waves.where.not(status: ['completed', 'cancelled']).count rescue 0
    
    # Only count active receipts
    active_receipts_count = @warehouse.receipts.where.not(status: ['completed', 'cancelled']).count rescue 0
    
    # Only count active shipments
    active_shipments_count = @warehouse.shipments.where.not(status: ['cancelled', 'delivered']).count rescue 0
    
    blocking_reasons = []
    
    blocking_reasons << "#{zones_count} zona(s)" if zones_count > 0
    blocking_reasons << "#{active_orders_count} orden(es) activa(s)" if active_orders_count > 0
    blocking_reasons << "#{active_tasks_count} tarea(s) activa(s)" if active_tasks_count > 0
    blocking_reasons << "#{active_pick_lists_count} lista(s) de picking activa(s)" if active_pick_lists_count > 0
    blocking_reasons << "#{active_waves_count} wave(s) activa(s)" if active_waves_count > 0
    blocking_reasons << "#{active_receipts_count} recepción(es) activa(s)" if active_receipts_count > 0
    blocking_reasons << "#{active_shipments_count} envío(s) activo(s)" if active_shipments_count > 0
    
    if blocking_reasons.any?
      reasons_text = blocking_reasons.join(", ")
      alert_message = "No se puede eliminar el almacén '#{@warehouse.name}' porque tiene asociado(s): #{reasons_text}. " +
                     "Elimina o cancela estos elementos primero para poder eliminar el almacén."
      redirect_to admin_warehouse_path(@warehouse), alert: alert_message
    else
      @warehouse.destroy
      redirect_to admin_warehouses_path, notice: "Almacén '#{@warehouse.name}' eliminado exitosamente."
    end
  end

  private

  def set_warehouse
    @warehouse = Warehouse.find(params[:id])
  end

  def warehouse_params
    params.require(:warehouse).permit(:name, :code, :address, :active, :contact_info)
  end

  def authorize_warehouse_management!
    unless current_admin || current_user&.can?("manage_warehouses")
      redirect_to admin_root_path, alert: "No tienes permisos para gestionar almacenes."
    end
  end

  def authorize_warehouse_read!
    unless current_admin || current_user&.can?("read_warehouse")
      redirect_to admin_root_path, alert: "No tienes permisos para ver almacenes."
    end
  end
end
