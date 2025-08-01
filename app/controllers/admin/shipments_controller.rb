class Admin::ShipmentsController < AdminController
  before_action :set_shipment, only: [:show, :edit, :update, :destroy, :ship, :deliver]

  def index
    @shipments = Shipment.includes(:order, :warehouse, :admin)
                        .order(created_at: :desc)
                        .page(params[:page])
                        .per(20)

    @shipments = @shipments.by_status(params[:status]) if params[:status].present?
  end

  def show
    @order = @shipment.order
    @order_products = @order.order_products.includes(:product)
  end

  def new
    @shipment = Shipment.new
    @warehouses = Warehouse.active
    @orders = Order.where(status: 'confirmed').includes(:order_products)
  end

  def create
    @shipment = Shipment.new(shipment_params)
    @shipment.admin = current_admin

    if @shipment.save
      redirect_to admin_shipment_path(@shipment), notice: 'Envío creado exitosamente.'
    else
      @warehouses = Warehouse.active
      @orders = Order.where(status: 'confirmed').includes(:order_products)
      render :new
    end
  end

  def edit
    @warehouses = Warehouse.active
    @orders = Order.where(status: 'confirmed').includes(:order_products)
  end

  def update
    if @shipment.update(shipment_params)
      redirect_to admin_shipment_path(@shipment), notice: 'Envío actualizado exitosamente.'
    else
      @warehouses = Warehouse.active
      @orders = Order.where(status: 'confirmed').includes(:order_products)
      render :edit
    end
  end

  def destroy
    if @shipment.status == 'preparing'
      @shipment.destroy
      redirect_to admin_shipments_path, notice: 'Envío eliminado exitosamente.'
    else
      redirect_to admin_shipments_path, alert: 'No se puede eliminar un envío ya despachado.'
    end
  end

  def ship
    if @shipment.ship!
      redirect_to admin_shipment_path(@shipment), notice: 'Envío despachado exitosamente.'
    else
      redirect_to admin_shipments_path, alert: 'No se pudo despachar el envío.'
    end
  end

  def deliver
    if @shipment.deliver!
      redirect_to admin_shipment_path(@shipment), notice: 'Envío entregado exitosamente.'
    else
      redirect_to admin_shipments_path, alert: 'No se pudo marcar como entregado el envío.'
    end
  end

  private

  def set_shipment
    @shipment = Shipment.find(params[:id])
  end

  def shipment_params
    params.require(:shipment).permit(:order_id, :warehouse_id, :tracking_number, 
                                    :carrier, :notes)
  end
end