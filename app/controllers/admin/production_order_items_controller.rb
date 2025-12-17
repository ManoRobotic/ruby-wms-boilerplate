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

    # Imprimir los datos de las etiquetas en la consola
    production_order_items.each do |item|
      Rails.logger.info "Label data for item #{item.id}: #{item.label_data.to_json}"
    end

    # Marcar como impresos
    if production_order_items.update_all(print_status: :printed)
      respond_to do |format|
        format.turbo_stream { head :ok }
        format.json { render json: { success: true, message: "Items marked as printed.", items: production_order_items.map(&:label_data) } }
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.json { render json: { success: false, error: "Failed to mark items as printed." }, status: :unprocessable_entity }
      end
    end
  end

  def show_print_confirmation
    @production_order = ProductionOrder.find(params[:production_order_id])
    @item_ids = params[:item_ids].split(',') if params[:item_ids].present?
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.append(
          "body",
          partial: "admin/production_order_items/confirm_print_modal",
          locals: { 
            production_order: @production_order, 
            item_ids: @item_ids || []
          }
        )
      end
      format.html do
        render partial: "admin/production_order_items/confirm_print_modal", 
               locals: { 
                 production_order: @production_order, 
                 item_ids: @item_ids || [] 
               }, 
               layout: false,
               content_type: 'text/html'
      end
      format.json do
        render json: { 
          production_order_id: @production_order.id,
          item_ids: @item_ids || []
        }
      end
    end
  end

  def confirm_print
    item_ids = params[:item_ids].split(',') if params[:item_ids].present?
    production_order_items = ProductionOrderItem.where(id: item_ids)

    # Imprimir los datos de las etiquetas en la consola
    production_order_items.each do |item|
      Rails.logger.info "Label data for item #{item.id}: #{item.label_data.to_json}"
      # También imprimir en la consola del navegador para debugging
      puts "Label data for item #{item.id}: #{item.label_data.to_json}"
    end

    # Determine the company to use for the printing service
    company = current_admin&.company || current_user&.company
    
    # Store successful prints to mark them later
    successfully_printed_items = []
    failed_items = []
    
    # Verify the serial service is accessible before attempting to print
    if company&.serial_service_url_configured? && SerialCommunicationService.health_check(company: company)
      Rails.logger.info "Serial server is accessible, proceeding with printing"

      production_order_items.each do |item|
        data = item.label_data
        
        # Crear contenido de la etiqueta en formato TSPL2 para la impresora
        label_content = generate_tspl2_label_content(data)
        Rails.logger.info "Generated label content for item #{item.id}: #{label_content}"

        # Try to print
        print_result = print_with_retry(label_content, company)
        
        if print_result
          successfully_printed_items << item
          Rails.logger.info "Item #{item.id} printed successfully"
        else
          failed_items << item
          Rails.logger.error "Failed to print item #{item.id}"
        end
      end
    else
      Rails.logger.info "Serial service not configured or not accessible"
      failed_items = production_order_items.to_a
    end

    # Marcar como impresos solo los que se imprimieron correctamente
    if successfully_printed_items.any?
      ProductionOrderItem.where(id: successfully_printed_items.map(&:id)).update_all(print_status: :printed)
    end

    # Send response
    all_success = failed_items.empty?
    
    # Recargar los items para obtener el estado actualizado
    updated_items = ProductionOrderItem.where(id: item_ids)
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("confirm-print-modal"),
          turbo_stream.append(
            "flashes",
            partial: all_success ? "shared/toast/toast_success" : "shared/toast/toast_danger",
            locals: { message: all_success ? "Items marcados como impresos y enviados a la impresora." : "Hubo un problema al enviar a la impresora. Se imprimieron #{successfully_printed_items.count} de #{production_order_items.count} etiquetas." }
          )
        ] + updated_items.map { |item|
          turbo_stream.replace(
            "production_order_item_#{item.id}_print_status",
            partial: "admin/production_order_items/print_status",
            locals: { item: item.reload }
          )
        }
      end
      format.json { 
        render json: { 
          success: all_success, 
          message: all_success ? "Items marked as printed and sent to printer." : "Some items failed to print.", 
          printed_count: successfully_printed_items.count,
          failed_count: failed_items.count,
          items: production_order_items.map(&:label_data)
        } 
      }
    end
  end

  private

  def print_with_retry(label_content, company)
    # First attempt
    result = SerialCommunicationService.print_label(
      label_content,
      ancho_mm: 80,
      alto_mm: 50,
      company: company
    )
    
    return true if result
    
    # If failed, try to connect printer and current settings
    Rails.logger.info "Print failed, attempting to connect printer and retry..."
    
    if SerialCommunicationService.connect_printer(company: company)
      # Second attempt after connection
      SerialCommunicationService.print_label(
        label_content,
        ancho_mm: 80,
        alto_mm: 50,
        company: company
      )
    else
      false
    end
  end

  private

  def set_production_order
    @production_order = ProductionOrder.find(params[:production_order_id])
  end

  def set_production_order_item
    @production_order_item = @production_order.production_order_items.includes(:production_order).find(params[:id])
  end

  def post_serial_endpoint(endpoint, payload, company = nil)
    SerialCommunicationService.send(:post, endpoint, payload: payload, company: company)
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

  # Generate TSPL2 label content for the printer
  def generate_tspl2_label_content(label_data)
    Rails.logger.info "Generating TSPL2 label content with data: #{label_data}"

    # Prepare label content in TSPL2 format for TSC printers with complete initialization sequence
    tspl2_commands = [
      "SIZE 80 mm, 50 mm",     # Tamaño de la etiqueta
      "GAP 2 mm, 0 mm",        # Espacio entre etiquetas
      "DIRECTION 1,0",         # Dirección
      "REFERENCE 0,0",         # Punto de referencia
      "OFFSET 0 mm",           # Offset
      "SET PEEL OFF",          # Modo peeling desactivado
      "SET CUTTER OFF",        # Cortador desactivado
      "SET PARTIAL_CUTTER OFF", # Cortador parcial desactivado
      "SET TEAR ON",           # Modo tear activado
      "CLS",                   # Limpiar buffer de impresión
      "CODEPAGE 1252"          # Página de códigos occidental
    ]

    # Add content - adjust positioning as needed
    tspl2_commands << "TEXT 160,75,\"4\",0,1,1,\"#{label_data[:name] || 'N/A'}\""
    tspl2_commands << "TEXT 160,150,\"3\",0,1,1,\"Lote: #{label_data[:lote] || 'N/A'}\""
    tspl2_commands << "TEXT 160,225,\"3\",0,1,1,\"Producto: #{label_data[:clave_producto] || 'N/A'}\""
    tspl2_commands << "TEXT 160,300,\"3\",0,1,1,\"Peso Bruto: #{label_data[:peso_bruto] || 0} kg\""
    tspl2_commands << "TEXT 160,375,\"3\",0,1,1,\"Peso Neto: #{label_data[:peso_neto] || 0} kg\""
    tspl2_commands << "TEXT 160,450,\"2\",0,1,1,\"#{label_data[:cliente] || 'N/A'}\""
    tspl2_commands << "TEXT 160,525,\"2\",0,1,1,\"Orden: #{label_data[:numero_de_orden] || 'N/A'}\""
    tspl2_commands << "TEXT 160,600,\"1\",0,1,1,\"#{label_data[:fecha_creacion] || 'N/A'}\""

    # Print command
    tspl2_commands << "PRINT 1,1"

    label_content = tspl2_commands.join("\n") + "\n"
    Rails.logger.info "Generated TSPL2 label content: #{label_content}"

    # Return the label content string
    label_content
  end
end
