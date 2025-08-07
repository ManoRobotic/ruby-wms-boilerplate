class Admin::OrdersController < AdminController
  before_action :set_order, only: %i[ show edit update destroy cancel mark_delivered ]

  # GET /admin/orders or /admin/orders.json
  def index
    @admin_orders = Order.includes(:warehouse).where(fulfilled: true).order(created_at: :desc).page(params[:paid_page]).per(5)
    @not_fulfilled_orders = Order.includes(:warehouse).where(fulfilled: false).order(created_at: :desc).page(params[:unpaid_page]).per(5)
  end

  # GET /admin/orders/1 or /admin/orders/1.json
  def show
  end

  # GET /admin/orders/new
  def new
    @admin_order = Order.new
  end

  # GET /admin/orders/1/edit
  def edit
  end

  # POST /admin/orders or /admin/orders.json
  def create
    @admin_order = Order.new(order_params)

    respond_to do |format|
      if @admin_order.save
        format.html { redirect_to admin_orders_path(@admin_order), notice: t("admin.orders.created") }
        format.json { render :show, status: :created, location: admin_order_path(@admin_order) }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @admin_order.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /admin/orders/1 or /admin/orders/1.json
  def update
    respond_to do |format|
      if @admin_order.update(order_params)
        format.html { redirect_to admin_orders_path(@admin_order), notice: t("admin.orders.updated") }
        format.json { render :show, status: :ok, location: admin_order_path(@admin_order) }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @admin_order.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH /admin/orders/1/cancel
  def cancel
    @admin_order.update!(status: :cancelled, fulfillment_status: "cancelled")
    redirect_to admin_order_path(@admin_order), notice: "Orden cancelada exitosamente."
  rescue => e
    redirect_to admin_order_path(@admin_order), alert: "Error al cancelar la orden: #{e.message}"
  end

  # PATCH /admin/orders/1/mark_delivered
  def mark_delivered
    @admin_order.update!(status: :delivered, fulfillment_status: "delivered")
    redirect_to admin_order_path(@admin_order), notice: "Orden marcada como entregada exitosamente."
  rescue => e
    redirect_to admin_order_path(@admin_order), alert: "Error al marcar la orden como entregada: #{e.message}"
  end

  # DELETE /admin/orders/1 or /admin/orders/1.json
  def destroy
    # Check if order can be deleted based on status and dependencies
    unless can_delete_order?
      redirect_to admin_order_path(@admin_order), alert: get_delete_error_message
      return
    end

    begin
      @admin_order.destroy!
      respond_to do |format|
        format.html { redirect_to admin_orders_path, status: :see_other, notice: "Orden eliminada exitosamente." }
        format.json { head :no_content }
      end
    rescue => e
      respond_to do |format|
        format.html { redirect_to admin_order_path(@admin_order), alert: "Error al eliminar la orden: #{e.message}" }
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  private
    def set_order
      @admin_order = Order.find(params[:id])
    end

    def order_params
      params.require(:order).permit(:customer_email, :fulfilled, :total, :address, :status)
    end

    def can_delete_order?
      # Can only delete cancelled or delivered orders (check both status fields)
      status_allows_deletion = @admin_order.cancelled? || @admin_order.delivered?
      fulfillment_allows_deletion = @admin_order.fulfillment_status.in?([ "cancelled", "delivered" ])

      return false unless status_allows_deletion || fulfillment_allows_deletion

      # Check for blocking dependencies
      blocking_items = get_blocking_dependencies
      blocking_items.empty?
    end

    def get_blocking_dependencies
      blocking = []

      # Check pick lists - only active ones
      active_pick_lists = @admin_order.pick_lists.where(status: [ "pending", "assigned", "in_progress" ])
      blocking << "#{active_pick_lists.count} lista(s) de picking activa(s)" if active_pick_lists.any?

      # Check shipments - only active ones
      active_shipments = @admin_order.shipments.where.not(status: [ "cancelled", "delivered" ])
      blocking << "#{active_shipments.count} envío(s) activo(s)" if active_shipments.any?

      # For delivered orders, don't check inventory transactions since they're completed
      # For cancelled orders, inventory transactions might need cleanup but shouldn't block deletion

      blocking
    end

    def get_delete_error_message
      status_allows_deletion = @admin_order.cancelled? || @admin_order.delivered?
      fulfillment_allows_deletion = @admin_order.fulfillment_status.in?([ "cancelled", "delivered" ])

      unless status_allows_deletion || fulfillment_allows_deletion
        return "Solo se pueden eliminar órdenes canceladas o entregadas. Estado: #{@admin_order.status&.humanize || 'No definido'}, Fulfillment: #{@admin_order.fulfillment_status&.humanize || 'No definido'}."
      end

      blocking_items = get_blocking_dependencies
      if blocking_items.any?
        return "No se puede eliminar la orden porque tiene: #{blocking_items.join(', ')}. Elimina o cancela estos elementos primero."
      end

      "No se puede eliminar esta orden."
    end
end
