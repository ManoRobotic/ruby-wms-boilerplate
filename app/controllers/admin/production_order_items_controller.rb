class Admin::ProductionOrderItemsController < AdminController
  before_action :set_production_order
  before_action :set_production_order_item, only: [ :show, :edit, :update, :destroy ]

  def index
    @production_order_items = @production_order.production_order_items.order(:folio_consecutivo)
  end

  def show
  end

  def new
    @production_order_item = @production_order.production_order_items.build
    # Generar folio consecutivo automáticamente
    @production_order_item.folio_consecutivo = ProductionOrderItem.generate_folio_consecutivo(@production_order)

    # Pre-llenar con datos del packing record si existe
    if @production_order.packing_records.any?
      packing_record = @production_order.packing_records.first
      @production_order_item.micras = packing_record.micras
      @production_order_item.ancho_mm = packing_record.ancho_mm
    end
  end

  def create
    @production_order_item = @production_order.production_order_items.build(production_order_item_params)

    # Generar folio consecutivo si no se proporciona
    if @production_order_item.folio_consecutivo.blank?
      @production_order_item.folio_consecutivo = ProductionOrderItem.generate_folio_consecutivo(@production_order)
    end

    if @production_order_item.save
      respond_to do |format|
        format.html do
          redirect_to admin_production_order_path(@production_order),
                      notice: "Consecutivo #{@production_order_item.folio_consecutivo} creado exitosamente."
        end
        format.json do
          render json: {
            status: "success",
            message: "Consecutivo #{@production_order_item.folio_consecutivo} creado exitosamente.",
            item: @production_order_item
          }
        end
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json do
          render json: {
            status: "error",
            errors: @production_order_item.errors.full_messages
          }
        end
      end
    end
  end

  def edit
  end

  def update
    if @production_order_item.update(production_order_item_params)
      redirect_to admin_production_order_path(@production_order),
                  notice: "Consecutivo actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    folio = @production_order_item.folio_consecutivo
    @production_order_item.destroy
    redirect_to admin_production_order_path(@production_order),
                notice: "Consecutivo #{folio} eliminado exitosamente."
  end

  private

  def set_production_order
    @production_order = ProductionOrder.find(params[:production_order_id])
  end

  def set_production_order_item
    @production_order_item = @production_order.production_order_items.find(params[:id])
  end

  def production_order_item_params
    params.require(:production_order_item).permit(
      :folio_consecutivo, :peso_bruto, :peso_neto, :metros_lineales,
      :peso_core_gramos, :status, :micras, :ancho_mm, :altura_cm,
      :cliente, :numero_de_orden, :nombre_cliente_numero_pedido
    )
  end
end
