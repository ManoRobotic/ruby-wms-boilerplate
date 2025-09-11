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

    # Generar folio consecutivo si no se proporciona o regenerar si hay conflicto
    if @production_order_item.folio_consecutivo.blank?
      @production_order_item.folio_consecutivo = ProductionOrderItem.generate_folio_consecutivo(@production_order)
    end

    # Intentar guardar, y si hay error de duplicado, regenerar el folio
    unless @production_order_item.save
      if @production_order_item.errors[:folio_consecutivo].any?
        # Regenerar folio si hay error de duplicado
        @production_order_item.folio_consecutivo = ProductionOrderItem.generate_folio_consecutivo(@production_order)
        @production_order_item.save
      end
    end

    if @production_order_item.persisted?
      Rails.logger.info "Production order item saved successfully, responding with turbo_stream"
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
        format.turbo_stream do
          Rails.logger.info "Rendering turbo_stream template for create"
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
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "consecutivo-modal",
            partial: "admin/production_orders/consecutivo_modal_with_errors",
            locals: { production_order: @production_order, production_order_item: @production_order_item }
          )
        end
      end
    end
  end

  def edit
    Rails.logger.info "Loading edit form for production order item: #{@production_order_item.id}"
    respond_to do |format|
      format.html # This will render the edit.html.erb template
    end
  end

  def update
    Rails.logger.info "Received update request for production order item: #{@production_order_item.id}"
    Rails.logger.info "Updating production order item with params: #{params.inspect}"
    
    if @production_order_item.update(production_order_item_params)
      Rails.logger.info "Update successful for item: #{@production_order_item.inspect}"
      respond_to do |format|
        format.html do
          redirect_to admin_production_order_path(@production_order),
                      notice: "Consecutivo actualizado exitosamente."
        end
        format.json do
          render json: {
            status: "success",
            message: "Consecutivo actualizado exitosamente.",
            item: @production_order_item
          }
        end
        format.turbo_stream
      end
    else
      Rails.logger.info "Update failed. Errors: #{@production_order_item.errors.full_messages}"
      Rails.logger.info "Permitted params: #{production_order_item_params.inspect}"
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json do
          render json: {
            status: "error",
            errors: @production_order_item.errors.full_messages
          }
        end
      end
    end
  end

  def destroy
    folio = @production_order_item.folio_consecutivo
    @production_order_item.destroy
    redirect_to admin_production_order_path(@production_order),
                notice: "Consecutivo #{folio} eliminado exitosamente."
  end

  def mark_as_printed
    item_ids = params[:item_ids]
    production_order_items = ProductionOrderItem.where(id: item_ids)

    if production_order_items.update_all(print_status: :printed)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: production_order_items.map do |item|
            turbo_stream.replace(
              "production_order_item_#{item.id}_print_status", # Unique ID for the TD
              partial: "admin/production_order_items/print_status",
              locals: { item: item }
            )
          end
        end
        format.json { render json: { success: true, message: "Items marked as printed." } } # Keep JSON for now, might remove later
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity } # Or render an error message
        format.json { render json: { success: false, error: "Failed to mark items as printed." }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_production_order
    @production_order = ProductionOrder.find(params[:production_order_id])
  end

  def set_production_order_item
    @production_order_item = @production_order.production_order_items.includes(:production_order).find(params[:id])
  end

  def production_order_item_params
    item_params = params.require(:production_order_item).permit(
      :folio_consecutivo, :peso_bruto, :peso_neto, :metros_lineales,
      :peso_core_gramos, :status, :micras, :ancho_mm, :altura_cm,
      :cliente, :numero_de_orden, :nombre_cliente_numero_pedido, :peso_bruto_manual
    )
    # If peso_bruto_manual is present and not empty, use it as peso_bruto
    if item_params[:peso_bruto_manual].present?
      item_params[:peso_bruto] = item_params[:peso_bruto_manual]
    end
    item_params.except(:peso_bruto_manual)
  end
end
