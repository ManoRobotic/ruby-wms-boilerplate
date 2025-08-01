class Admin::PickListsController < AdminController
  before_action :set_pick_list, only: [ :show, :edit, :update, :destroy, :assign, :start, :complete, :cancel ]
  before_action :authorize_pick_list_management!, except: [ :index, :show ]
  before_action :authorize_pick_list_read!, only: [ :index, :show ]
  before_action :check_pick_list_warehouse_access!, only: [ :show, :edit, :update, :destroy, :assign, :start, :complete, :cancel ]

  def index
    @pick_lists = PickList.includes(:order, :warehouse, :admin, :pick_list_items)

    # Filter by user's warehouse if not admin
    if current_user && current_user.warehouse_id.present?
      @pick_lists = @pick_lists.by_warehouse(current_user.warehouse_id)
    end

    # Additional filters
    @pick_lists = @pick_lists.by_warehouse(params[:warehouse_id]) if params[:warehouse_id].present? && current_admin
    @pick_lists = @pick_lists.by_status(params[:status]) if params[:status].present?
    @pick_lists = @pick_lists.by_priority(params[:priority]) if params[:priority].present?
    @pick_lists = @pick_lists.by_admin(params[:admin_id]) if params[:admin_id].present?

    # Default ordering
    @pick_lists = @pick_lists.by_priority_order.recent
                             .page(params[:page])
                             .per(20)

    @pick_list_stats = {
      pending: PickList.pending.count,
      in_progress: PickList.in_progress.count,
      completed_today: PickList.completed.where(completed_at: Date.current.beginning_of_day..Date.current.end_of_day).count,
      overdue: PickList.overdue.count
    }
  end

  def show
    @pick_list_items = @pick_list.pick_list_items.includes(:product, :location)
                                 .order(:sequence_number, :id)
    @completion_percentage = @pick_list.completion_percentage rescue 0
    @estimated_completion = @pick_list.estimated_completion_time rescue nil
  end

  def new
    @pick_list = PickList.new
    @orders = Order.where(fulfillment_status: "pending").includes(:order_products)
    @warehouses = Warehouse.active
  end

  def create
    @pick_list = PickList.new(pick_list_params)
    @pick_list.admin = current_admin

    if @pick_list.save
      redirect_to admin_pick_lists_path, notice: "Lista de picking creada exitosamente."
    else
      @orders = Order.where(fulfillment_status: "pending").includes(:order_products)
      @warehouses = Warehouse.active
      render :new
    end
  end

  def edit
    @orders = Order.where(fulfillment_status: "pending").includes(:order_products)
    @warehouses = Warehouse.active
  end

  def update
    if @pick_list.update(pick_list_params)
      redirect_to admin_pick_list_path(@pick_list), notice: "Pick list was successfully updated."
    else
      @orders = Order.where(fulfillment_status: "pending").includes(:order_products)
      @warehouses = Warehouse.active
      render :edit
    end
  end

  def destroy
    if @pick_list.pending?
      @pick_list.destroy
      redirect_to admin_pick_lists_path, notice: "Pick list was successfully deleted."
    else
      redirect_to admin_pick_list_path(@pick_list), alert: "Cannot delete pick list that is not pending."
    end
  end

  # WMS Actions
  def assign
    admin_id = params[:admin_id] || current_admin.id
    admin = Admin.find(admin_id)

    if @pick_list.assign_to!(admin)
      redirect_to admin_pick_list_path(@pick_list), notice: "Pick list assigned successfully."
    else
      redirect_to admin_pick_list_path(@pick_list), alert: "Could not assign pick list."
    end
  end

  def start
    if @pick_list.start!
      redirect_to admin_pick_list_path(@pick_list), notice: "Pick list started successfully."
    else
      redirect_to admin_pick_list_path(@pick_list), alert: "Could not start pick list."
    end
  end

  def complete
    if @pick_list.complete!
      redirect_to admin_pick_list_path(@pick_list), notice: "Pick list completed successfully."
    else
      redirect_to admin_pick_list_path(@pick_list), alert: "Could not complete pick list. Ensure all items are picked."
    end
  end

  def cancel
    reason = params[:cancellation_reason]
    if @pick_list.cancel!(reason)
      redirect_to admin_pick_list_path(@pick_list), notice: "Pick list cancelled successfully."
    else
      redirect_to admin_pick_list_path(@pick_list), alert: "Could not cancel pick list."
    end
  end

  # Generate pick list for order
  def generate_for_order
    order = Order.find(params[:order_id])

    if order.can_create_pick_list?
      pick_list = order.create_pick_list!(current_admin)
      if pick_list
        redirect_to admin_pick_list_path(pick_list), notice: "Pick list generated successfully."
      else
        redirect_to admin_order_path(order), alert: "Could not generate pick list."
      end
    else
      redirect_to admin_order_path(order), alert: "Order is not ready for pick list generation."
    end
  end

  # Optimize route
  def optimize_route
    PickListItem.optimize_sequence_by_route(@pick_list)
    redirect_to admin_pick_list_path(@pick_list), notice: "Pick list route optimized."
  end

  private

  def set_pick_list
    @pick_list = PickList.find(params[:id])
  end

  def pick_list_params
    params.require(:pick_list).permit(:order_id, :warehouse_id, :priority, :status)
  end

  def authorize_pick_list_management!
    unless current_admin || current_user&.can?("create_pick_lists")
      redirect_to admin_root_path, alert: "No tienes permisos para gestionar listas de picking."
    end
  end

  def authorize_pick_list_read!
    unless current_admin || current_user&.can?("read_pick_lists")
      redirect_to admin_root_path, alert: "No tienes permisos para ver listas de picking."
    end
  end

  def check_pick_list_warehouse_access!
    if current_user && current_user.warehouse_id.present?
      unless @pick_list.warehouse_id == current_user.warehouse_id
        redirect_to admin_pick_lists_path, alert: "No tienes acceso a listas de picking de este almacén."
      end
    end
  end
end
