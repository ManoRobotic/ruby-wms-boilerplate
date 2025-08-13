class Admin::ProductionOrdersController < AdminController
  before_action :set_production_order, only: [ :show, :edit, :update, :destroy, :start, :pause, :complete, :cancel, :print_bag_format, :print_box_format, :update_weight, :modal_details ]

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
      # Send notifications to all users who should be notified about production orders
      notification_data = {
        production_order_id: @production_order.id,
        order_number: @production_order.no_opro || @production_order.order_number,
        product_name: @production_order.product.name,
        quantity: @production_order.quantity_requested,
        status: @production_order.status
      }.to_json

      # Create individual notifications for each relevant user
      User.where(role: ['admin', 'manager', 'supervisor', 'operador']).find_each do |user|
        Notification.create!(
          user_id: user.id,
          notification_type: "production_order_created",
          title: "Nueva orden de producción creada",
          message: "Se ha creado la orden de producción #{@production_order.no_opro || @production_order.order_number} para el producto #{@production_order.product.name}",
          action_url: "/admin/production_orders/#{@production_order.id}",
          data: notification_data
        )
      end

      respond_to do |format|
        format.html do
          redirect_to admin_production_order_path(@production_order),
                      notice: "Orden de producción creada exitosamente."
        end
        format.json do
          render json: {
            status: 'success',
            message: 'Orden de producción creada exitosamente',
            production_order: {
              id: @production_order.id,
              order_number: @production_order.no_opro || @production_order.order_number,
              product_name: @production_order.product.name
            }
          }
        end
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @production_order.update(production_order_params)
      redirect_to admin_production_order_path(@production_order),
                  notice: "Orden de producción actualizada exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @production_order.can_be_started? || @production_order.pending?
      @production_order.destroy
      redirect_to admin_production_orders_path,
                  notice: "Orden de producción eliminada exitosamente."
    else
      redirect_to admin_production_orders_path,
                  alert: "No se puede eliminar una orden de producción en progreso."
    end
  end

  def start
    if @production_order.start!
      redirect_to admin_production_order_path(@production_order),
                  notice: "Orden de producción iniciada."
    else
      redirect_to admin_production_order_path(@production_order),
                  alert: "No se pudo iniciar la orden de producción."
    end
  end

  def pause
    if @production_order.pause!
      redirect_to admin_production_order_path(@production_order),
                  notice: "Orden de producción pausada."
    else
      redirect_to admin_production_order_path(@production_order),
                  alert: "No se pudo pausar la orden de producción."
    end
  end

  def complete
    if @production_order.complete!
      redirect_to admin_production_order_path(@production_order),
                  notice: "Orden de producción completada."
    else
      redirect_to admin_production_order_path(@production_order),
                  alert: "No se pudo completar la orden de producción."
    end
  end

  def cancel
    reason = params[:reason]
    if @production_order.cancel!(reason)
      redirect_to admin_production_order_path(@production_order),
                  notice: "Orden de producción cancelada."
    else
      redirect_to admin_production_order_path(@production_order),
                  alert: "No se pudo cancelar la orden de producción."
    end
  end

  def print_bag_format
    respond_to do |format|
      format.html { render "print_bag_format", layout: "print" }
    end
  end

  def print_box_format
    respond_to do |format|
      format.html { render "print_box_format", layout: "print" }
    end
  end

  def scan_barcode_page
  end

  def scan_barcode
    begin
      barcode_data = JSON.parse(params[:barcode_data])

      production_order = ProductionOrder.find(barcode_data["id"])

      format_data = case barcode_data["format"]
      when "bag"
        {
          format: "Formato Bolsa",
          bolsa: barcode_data["bolsa"],
          medida_bolsa: barcode_data["medida_bolsa"],
          numero_piezas: barcode_data["numero_piezas"]
        }
      when "box"
        {
          format: "Formato Caja",
          bolsa: barcode_data["bolsa"],
          medida_bolsa: barcode_data["medida_bolsa"],
          numero_piezas: barcode_data["numero_piezas"],
          cantidad_paquetes: barcode_data["cantidad_paquetes"],
          medida_paquetes: barcode_data["medida_paquetes"]
        }
      else
        { error: "Formato no reconocido" }
      end

      render json: {
        success: true,
        production_order: {
          order_number: production_order.order_number,
          product: barcode_data["product"],
          created_at: barcode_data["created_at"]
        },
        format_data: format_data
      }

    rescue JSON::ParserError
      render json: { success: false, error: "Datos de código de barras inválidos" }, status: 400
    rescue ActiveRecord::RecordNotFound
      render json: { success: false, error: "Orden de producción no encontrada" }, status: 404
    rescue => e
      render json: { success: false, error: "Error interno del servidor" }, status: 500
    end
  end

  def import_excel
    begin
      file_path = Rails.root.join("FE BASE DE DATOS.xlsx")

      unless File.exist?(file_path)
        redirect_to admin_production_orders_path, alert: "Archivo FE BASE DE DATOS.xlsx no encontrado"
        return
      end

      import_service = ExcelImportService.new(file_path)
      results = import_service.import_production_orders

      if results[:errors].empty?
        redirect_to admin_production_orders_path,
                    notice: "Importación exitosa: #{results[:created]} creados, #{results[:updated]} actualizados"
      else
        error_message = "Importación completada con errores: #{results[:created]} creados, #{results[:updated]} actualizados, #{results[:errors].size} errores"
        redirect_to admin_production_orders_path, alert: error_message
      end

    rescue => e
      redirect_to admin_production_orders_path, alert: "Error al importar: #{e.message}"
    end
  end

  def update_weight
    peso = params[:peso]

    if peso.present? && @production_order.update(peso: peso.to_f)
      render json: {
        success: true,
        message: "Peso actualizado: #{peso} kg",
        peso: @production_order.peso
      }
    else
      render json: {
        success: false,
        error: "Error al actualizar el peso"
      }
    end
  end

  def modal_details
    render json: {
      id: @production_order.id,
      order_number: @production_order.order_number,
      no_opro: @production_order.no_opro,
      product_name: @production_order.product.name,
      warehouse_name: @production_order.warehouse.name,
      status: @production_order.status,
      priority: @production_order.priority,
      quantity_requested: @production_order.quantity_requested,
      quantity_produced: @production_order.quantity_produced || 0,
      lote_referencia: @production_order.lote_referencia,
      carga_copr: @production_order.carga_copr,
      peso: @production_order.peso,
      ano: @production_order.ano,
      mes: @production_order.mes,
      fecha_completa: @production_order.fecha_completa&.strftime("%d/%m/%Y"),
      created_at: @production_order.created_at.strftime("%d/%m/%Y %H:%M"),
      updated_at: @production_order.updated_at.strftime("%d/%m/%Y %H:%M"),
      progress_percentage: @production_order.progress_percentage,
      notes: @production_order.notes,
      can_be_started: @production_order.can_be_started?,
      can_be_paused: @production_order.can_be_paused?,
      can_be_completed: @production_order.can_be_completed?,
      can_be_cancelled: @production_order.can_be_cancelled?
    }
  end

  private

  def set_production_order
    @production_order = ProductionOrder.find(params[:id])
  end

  def production_order_params
    params.require(:production_order).permit(
      :warehouse_id, :product_id, :quantity_requested, :quantity_produced,
      :priority, :estimated_completion, :notes, :bag_size, :bag_measurement,
      :pieces_count, :package_count, :package_measurement, :peso, :lote_referencia,
      :no_opro, :carga_copr, :ano, :mes, :fecha_completa
    )
  end
end
