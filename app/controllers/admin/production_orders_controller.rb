class Admin::ProductionOrdersController < AdminController
  before_action :set_production_order, only: [:show, :edit, :update, :destroy, :start, :pause, :complete, :cancel]

  def index
    @production_orders = ProductionOrder.includes(:warehouse, :product)

    # Search
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @production_orders = @production_orders.joins(:product)
                                            .where("production_orders.order_number ILIKE ? OR products.name ILIKE ?", 
                                                  search_term, search_term)
    end

    # Filters
    @production_orders = @production_orders.by_warehouse(params[:warehouse_id]) if params[:warehouse_id].present?
    @production_orders = @production_orders.by_status(params[:status]) if params[:status].present?
    @production_orders = @production_orders.by_priority(params[:priority]) if params[:priority].present?

    # Date range filter
    if params[:start_date].present? && params[:end_date].present?
      start_date = Date.parse(params[:start_date]) rescue Date.current.beginning_of_month
      end_date = Date.parse(params[:end_date]) rescue Date.current
      @production_orders = @production_orders.by_date_range(start_date, end_date)
    end

    # Filter by user's warehouse if not admin
    if current_user && current_user.warehouse_id.present?
      @production_orders = @production_orders.by_warehouse(current_user.warehouse_id)
    end

    @production_orders = @production_orders.recent.page(params[:page]).per(20)
  end

  def show
  end

  def new
    @production_order = ProductionOrder.new
    if current_user && current_user.warehouse_id.present?
      @production_order.warehouse_id = current_user.warehouse_id
    end
  end

  def create
    @production_order = ProductionOrder.new(production_order_params)
    @production_order.admin_id = current_user&.id || current_admin&.id

    if @production_order.save
      redirect_to admin_production_order_path(@production_order), 
                  notice: 'Orden de producción creada exitosamente.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @production_order.update(production_order_params)
      redirect_to admin_production_order_path(@production_order), 
                  notice: 'Orden de producción actualizada exitosamente.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @production_order.can_be_started? || @production_order.pending?
      @production_order.destroy
      redirect_to admin_production_orders_path, 
                  notice: 'Orden de producción eliminada exitosamente.'
    else
      redirect_to admin_production_orders_path, 
                  alert: 'No se puede eliminar una orden de producción en progreso.'
    end
  end

  def start
    if @production_order.start!
      redirect_to admin_production_order_path(@production_order), 
                  notice: 'Orden de producción iniciada.'
    else
      redirect_to admin_production_order_path(@production_order), 
                  alert: 'No se pudo iniciar la orden de producción.'
    end
  end

  def pause
    if @production_order.pause!
      redirect_to admin_production_order_path(@production_order), 
                  notice: 'Orden de producción pausada.'
    else
      redirect_to admin_production_order_path(@production_order), 
                  alert: 'No se pudo pausar la orden de producción.'
    end
  end

  def complete
    if @production_order.complete!
      redirect_to admin_production_order_path(@production_order), 
                  notice: 'Orden de producción completada.'
    else
      redirect_to admin_production_order_path(@production_order), 
                  alert: 'No se pudo completar la orden de producción.'
    end
  end

  def cancel
    reason = params[:reason]
    if @production_order.cancel!(reason)
      redirect_to admin_production_order_path(@production_order), 
                  notice: 'Orden de producción cancelada.'
    else
      redirect_to admin_production_order_path(@production_order), 
                  alert: 'No se pudo cancelar la orden de producción.'
    end
  end

  private

  def set_production_order
    @production_order = ProductionOrder.find(params[:id])
  end

  def production_order_params
    params.require(:production_order).permit(
      :warehouse_id, :product_id, :quantity_requested, :quantity_produced,
      :priority, :estimated_completion, :notes
    )
  end
end
