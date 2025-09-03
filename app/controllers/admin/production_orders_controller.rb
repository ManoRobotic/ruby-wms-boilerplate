class Admin::ProductionOrdersController < AdminController
  require 'net/http'

  before_action :set_production_order, only: [ :show, :edit, :update, :destroy, :start, :pause, :complete, :cancel, :print_bag_format, :print_box_format, :update_weight, :modal_details, :print_consecutivos ]

  def index
    Rails.logger.debug "--- ProductionOrdersController#index Debug ---"
    Rails.logger.debug "current_admin: #{current_admin.inspect}"
    Rails.logger.debug "current_user: #{current_user.inspect}"
    Rails.logger.debug "current_user role: #{current_user.role if current_user.present?}"
    Rails.logger.debug "current_user warehouse_id: #{current_user.warehouse_id if current_user.present?}"
    Rails.logger.debug "current_user super_admin_role: #{current_user.super_admin_role if current_user.present?}"

    # Comenzar con todas las órdenes de producción
    @production_orders = ProductionOrder.includes(:warehouse, :product, :packing_records)
    Rails.logger.debug "Total production orders: #{@production_orders.count}"

    # Aplicar filtros adicionales basados en el rol
    if current_admin.present?
      if current_admin.super_admin?
        # Super admin ya tiene todas las órdenes de su company
        Rails.logger.debug "Current admin is super admin"
        # Filtrar por company para super admins
        if current_admin.company_id
          @production_orders = @production_orders.where(company_id: current_admin.company_id)
          Rails.logger.debug "Filtered by admin company_id: #{current_admin.company_id}"
        end
      else
        # Regular admin ve órdenes asociadas con su admin_id
        @production_orders = @production_orders.where(admin_id: current_admin.id)
        Rails.logger.debug "Filtered by admin_id: #{current_admin.id}"
        # También filtrar por company
        if current_admin.company_id
          @production_orders = @production_orders.where(company_id: current_admin.company_id)
          Rails.logger.debug "Filtered by admin company_id: #{current_admin.company_id}"
        end
      end
    elsif current_user.present? && current_user.operador?
      Rails.logger.debug "Current user is operador"
      if current_user.super_admin_role.present?
        @production_orders = @production_orders.joins(:admin).where(admins: { super_admin_role: current_user.super_admin_role })
        Rails.logger.debug "Filtered by super_admin_role: #{current_user.super_admin_role}"
      else
        # Operator without a super_admin_role sees no orders
        @production_orders = ProductionOrder.none
        Rails.logger.debug "Operator without super_admin_role, showing no orders"
      end
    else
      # No authenticated user, or unknown role, show no orders
      @production_orders = ProductionOrder.none
      Rails.logger.debug "No authenticated user or unknown role, showing no orders"
      # Para otros usuarios, filtrar por company si está disponible
      if current_user&.company_id
        @production_orders = @production_orders.where(company_id: current_user.company_id)
        Rails.logger.debug "Filtered by user company_id: #{current_user.company_id}"
      end
    end

    Rails.logger.debug "Production orders after role filter: #{@production_orders.count}"

    # Search
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @production_orders = @production_orders.joins(:product)
                                            .where("production_orders.order_number ILIKE ? OR production_orders.no_opro ILIKE ? OR products.name ILIKE ? OR production_orders.lote_referencia ILIKE ?",
                                                  search_term, search_term, search_term, search_term)
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

    # Filter by user's warehouse if not admin or operador
    if current_user && current_user.warehouse_id.present? && !current_user.admin? && !current_user.operador?
      @production_orders = @production_orders.by_warehouse(current_user.warehouse_id)
    end

    @production_orders = @production_orders.recent.page(params[:page]).per(10)
    Rails.logger.debug "Final production orders count: #{@production_orders.count}"
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
    
    # Asignar company_id del usuario/admin actual
    if current_admin&.company_id
      @production_order.company_id = current_admin.company_id
    elsif current_user&.company_id
      @production_order.company_id = current_user.company_id
    end

    if @production_order.save
      Rails.logger.info "Production order saved successfully."
      
      # Send notifications to all users who should be notified about production orders
      notification_data = {
        production_order_id: @production_order.id,
        order_number: @production_order.no_opro || @production_order.order_number,
        product_name: @production_order.product.name,
        quantity: @production_order.quantity_requested,
        status: @production_order.status
      }.to_json
      Rails.logger.info "Notification data created: #{notification_data}"

      # Create notifications for all relevant users in the same company
      if @production_order.company
        Rails.logger.info "Production order has a company: #{@production_order.company.name}"
        target_users = User.where(company: @production_order.company, role: ['admin', 'manager', 'supervisor', 'operador'])
        Rails.logger.info "Target users for notification: #{target_users.pluck(:email)}"
        
        notification_records = target_users.map do |user|
          {
            user_id: user.id,
            company_id: @production_order.company_id,
            notification_type: "production_order_created",
            title: "Nueva orden de producción creada",
            message: "Se ha creado la orden de producción #{@production_order.no_opro || @production_order.order_number} para el producto #{@production_order.product.name}",
            action_url: "/admin/production_orders/#{@production_order.id}",
            data: notification_data,
            created_at: Time.current,
            updated_at: Time.current
          }
        end

        if notification_records.any?
          Rails.logger.info "Inserting #{notification_records.size} notification records."
          Notification.insert_all(notification_records)
          Rails.logger.info "Notification records inserted."
          
          # Expire notification caches for all target users BEFORE touching them
          # This ensures we're clearing the current cache entries
          target_users.find_each do |user|
            cache_key = "notifications_data:#{user.class.name.downcase}:#{user.id}:#{user.updated_at}"
            Rails.cache.delete(cache_key)
          end
          
          # Touch user records to update their updated_at timestamps
          # This ensures new cache entries will have different keys
          target_users.find_each(&:touch)
        else
          Rails.logger.info "No notification records to insert."
        end
      else
        Rails.logger.info "Production order does not have a company."
      end

      # Expire notification caches for all users in the company before broadcasting
      if @production_order.company
        User.where(company: @production_order.company, role: ['admin', 'manager', 'supervisor', 'operador']).find_each do |user|
          # Manually expire the cache by deleting the cache key
          cache_key = "notifications_data:#{user.class.name.downcase}:#{user.id}:#{user.updated_at}"
          Rails.cache.delete(cache_key)
        end
      end

      # Broadcast notifications to relevant users
      broadcast_notifications(@production_order)

      respond_to do |format|
        format.html do
          # Redirect to show page instead of index
          redirect_to admin_production_order_path(@production_order),
                      notice: "Orden de producción creada exitosamente."
        end
        format.json do
          render json: {
            status: 'success',
            message: 'Orden de producción creada exitosamente',
            toast: {
              type: 'success',
              title: 'Orden creada!',
              message: "Orden #{@production_order.no_opro || @production_order.order_number} creada exitosamente"
            },
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

  def test_broadcast
    Rails.logger.info "🧪 Manual broadcast test triggered"
    
    # Create test notification data
    notification_data = {
      title: "Test Notification!",
      message: "Esta es una prueba de notificación en tiempo real",
      type: "info",
      duration: 15000,
      timestamp: Time.current.iso8601
    }

    # Broadcast to all users
    User.where(role: ['admin', 'manager', 'supervisor', 'operador']).find_each do |user|
      channel_name = "notifications_#{user.id}"
      Rails.logger.info "🧪 Test broadcasting to: #{channel_name}"
      
      ActionCable.server.broadcast(
        channel_name,
        {
          type: 'new_notification',
          notification: notification_data
        }
      )
    end

    render json: { 
      status: 'success', 
      message: 'Test broadcast sent',
      notification: notification_data
    }
  end

  def sync_excel_data
    # Temporarily disabled due to deployment issues with missing 'ORDEN PRODUCCION' sheet
    # SyncExcelDataJob.perform_later
    redirect_to admin_production_orders_path, notice: "La sincronización de datos de Excel está temporalmente deshabilitada."
  end

  def sync_google_sheets_opro
    unless current_admin.google_sheets_configured?
      redirect_to admin_production_orders_path, 
                  alert: "Google Sheets no está configurado. Ve a Configuración para configurarlo."
      return
    end

    begin
      service = AdminGoogleSheetsService.new(current_admin)
      result = service.sync_production_orders
      
      if result[:success]
        redirect_to admin_production_orders_path, 
                    notice: "#{result[:message]}. #{result[:errors].any? ? "Errores: #{result[:errors].count}" : ""}"
      else
        redirect_to admin_production_orders_path, 
                    alert: "Error en la sincronización: #{result[:message]}"
      end
    rescue => e
      Rails.logger.error "Error en sync_google_sheets_opro para admin #{current_admin.email}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to admin_production_orders_path, 
                  alert: "Error inesperado durante la sincronización. Verifique la configuración."
    end
  end

  def print_selected
    order_ids = params[:order_ids]
    
    if order_ids.blank?
      redirect_to admin_production_orders_path, alert: "No se seleccionaron órdenes para imprimir."
      return
    end

    @production_orders = ProductionOrder.where(id: order_ids).includes(:warehouse, :product, :packing_records)
    
    respond_to do |format|
      format.html { render "print_selected", layout: "print" }
    end
  end

  def bulk_toggle_selection
    begin
      request_body = JSON.parse(request.body.read)
      order_ids = request_body['order_ids'] || []
      action = request_body['action'] # 'select_all' or 'deselect_all'
      
      # Validate input
      if order_ids.empty?
        render json: {
          status: 'error',
          message: 'No order IDs provided'
        }, status: 422
        return
      end
      
      # Ensure order_ids are strings for consistency
      order_ids = order_ids.map(&:to_s)
      
      # Get current selections from session
      selected_orders = get_selected_orders.map(&:to_s)
      
      case action
      when 'select_all'
        # Use array union for better performance
        selected_orders = (selected_orders + order_ids).uniq
      when 'deselect_all'
        # Use array subtraction for better performance
        selected_orders = selected_orders - order_ids
      else
        render json: {
          status: 'error',
          message: 'Invalid action'
        }, status: 422
        return
      end
      
      # Store back in session
      set_selected_orders(selected_orders)
      
      
      render json: {
        status: 'success',
        selected_count: selected_orders.count,
        action: action,
        processed_count: order_ids.size
      }
      
    rescue JSON::ParserError => e
      Rails.logger.error "JSON Parse Error in bulk_toggle_selection: #{e.message}"
      render json: {
        status: 'error',
        message: 'Invalid JSON format'
      }, status: 422
    rescue StandardError => e
      Rails.logger.error "Error in bulk_toggle_selection: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: {
        status: 'error',
        message: 'Internal server error'
      }, status: 500
    end
  end

  def selected_orders_data
    begin
      selected_order_ids = get_selected_orders
      
      if selected_order_ids.empty?
        render json: {
          status: 'success',
          data: [],
          count: 0,
          message: 'No hay Ordenes seleccionadas'
        }
        return
      end

      # Ensure consistent data types
      selected_order_ids = selected_order_ids.map(&:to_s).uniq

      @production_orders = ProductionOrder.where(id: selected_order_ids)
                                         .includes(:warehouse, :product, :packing_records)
    
    orders_data = @production_orders.map do |order|
      {
        id: order.id,
        order_number: order.order_number,
        no_opro: order.no_opro,
        product: {
          id: order.product.id,
          name: order.product.name
        },
        warehouse: {
          id: order.warehouse.id,
          name: order.warehouse.name
        },
        status: order.status,
        priority: order.priority,
        quantity_requested: order.quantity_requested,
        quantity_produced: order.quantity_produced,
        lote_referencia: order.lote_referencia,
        carga_copr: order.carga_copr,
        peso: order.peso,
        ano: order.ano,
        mes: order.mes,
        fecha_completa: order.fecha_completa,
        created_at: order.created_at,
        updated_at: order.updated_at,
        notes: order.notes,
        packing_records: order.packing_records.map do |record|
          {
            id: record.id,
            cve_prod: record.cve_prod,
            micras: record.micras,
            ancho_mm: record.ancho_mm,
            metros_lineales: record.metros_lineales,
            peso_bruto: record.peso_bruto,
            peso_neto: record.peso_neto
          }
        end,
        progress_percentage: order.progress_percentage,
        can_be_started: order.can_be_started?,
        can_be_paused: order.can_be_paused?,
        can_be_completed: order.can_be_completed?,
        can_be_cancelled: order.can_be_cancelled?
      }
    end
    
      
      render json: {
        status: 'success',
        data: orders_data,
        count: orders_data.length,
        message: "#{orders_data.length} Ordenes seleccionadas"
      }
    rescue StandardError => e
      Rails.logger.error "Error in selected_orders_data: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: {
        status: 'error',
        message: 'Error al obtener datos de Ordenes seleccionadas'
      }, status: 500
    end
  end

  def clear_all_selections
    previous_orders = get_selected_orders
    previous_count = previous_orders.count
    
    # Clear both session and cache
    session[:selected_production_orders] = nil
    session[:using_cache_storage] = false
    Rails.cache.delete(selection_cache_key)
    
    render json: {
      status: 'success',
      message: "Se eliminaron #{previous_count} órdenes de la selección",
      previous_count: previous_count,
      selected_count: 0
    }
  end

  def toggle_selection
    begin
      # Parse request body to get order_id
      request_body = JSON.parse(request.body.read)
      order_id = request_body['order_id']
      
      if order_id.blank?
        render json: {
          status: 'error',
          message: 'Order ID is required'
        }, status: 422
        return
      end
      
      @production_order = ProductionOrder.find(order_id)

      # Get current selections from cache
      selected_orders = get_selected_orders.map(&:to_s)
      order_id_str = @production_order.id.to_s
      
      if selected_orders.include?(order_id_str)
        selected_orders.delete(order_id_str)
        selected = false
      else
        selected_orders.push(order_id_str)
        selected = true
      end

      # Save back to cache
      set_selected_orders(selected_orders)


      render json: {
        status: 'success',
        selected: selected,
        selected_count: selected_orders.count
      }
    rescue JSON::ParserError => e
      Rails.logger.error "JSON Parse Error in toggle_selection: #{e.message}"
      render json: {
        status: 'error',
        message: 'Invalid JSON format'
      }, status: 422
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Order not found in toggle_selection: #{e.message}"
      render json: {
        status: 'error',
        message: 'Order not found'
      }, status: 404
    rescue StandardError => e
      Rails.logger.error "Error in toggle_selection: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: {
        status: 'error',
        message: 'Internal server error'
      }, status: 500
    end
  end

  def weigh_item
    admin = current_admin
    if admin.serial_port.blank?
      render json: { success: false, message: "Puerto serie no configurado." }
      return
    end

    command = [
      "python3",
      "serial_server.py",
      "--port", admin.serial_port,
      "--baudrate", admin.serial_baud_rate.to_s,
      "--parity", admin.serial_parity,
      "--stopbits", admin.serial_stop_bits.to_s,
      "--bytesize", admin.serial_data_bits.to_s
    ]

    # Check if the server is running
    # This is a simplified check, a more robust solution would be to store the PID
    # of the process in the database or a cache.
    begin
      response = Net::HTTP.get_response(URI("http://localhost:5000/health"))
      if response.is_a?(Net::HTTPSuccess)
        # Server is running, just read the weight
        read_response = Net::HTTP.get_response(URI("http://localhost:5000/scale/read"))
        if read_response.is_a?(Net::HTTPSuccess)
          render json: JSON.parse(read_response.body)
        else
          render json: { success: false, message: "Error al leer el peso." }
        end
        return
      end
    rescue Errno::ECONNREFUSED
      # Server is not running, start it
    end

    pid = Process.spawn(*command)
    Process.detach(pid)
    sleep 2 # Give the server some time to start

    begin
      read_response = Net::HTTP.get_response(URI("http://localhost:5000/scale/read"))
      if read_response.is_a?(Net::HTTPSuccess)
        render json: JSON.parse(read_response.body)
      else
        render json: { success: false, message: "Error al leer el peso." }
      end
    rescue Errno::ECONNREFUSED
      render json: { success: false, message: "No se pudo conectar con el servidor de pesaje." }
    end
  end

  def print_consecutivos
    respond_to do |format|
      format.pdf do
        pdf = ProductionOrderPdf.new(@production_order, @production_order.production_order_items)
        send_data pdf.render, 
                  filename: "consecutivos_#{@production_order.order_number}.pdf",
                  type: "application/pdf",
                  disposition: "attachment"
      end
    end
  end

  private

  def selection_cache_key
    # Use user ID and a stable session identifier
    user_id = current_user&.id || current_admin&.id || 'anonymous'
    
    # Create or get a stable session key for selections
    session[:selection_session_key] ||= SecureRandom.hex(16)
    selection_session = session[:selection_session_key]
    
    "selected_orders:#{user_id}:#{selection_session}"
  end

  def get_selected_orders
    # Check if using cache or session storage
    if session[:using_cache_storage]
      # Large selections are stored in cache
      cache_key = selection_cache_key
      selected_orders = Rails.cache.read(cache_key) || []
    else
      # Small selections are stored in session
      selected_orders = session[:selected_production_orders] || []
    end
    
    # Validate that the data is correct
    if selected_orders.present? && !selected_orders.is_a?(Array)
      # Reset both storages
      session[:selected_production_orders] = []
      Rails.cache.delete(selection_cache_key)
      session[:using_cache_storage] = false
      return []
    end
    
    selected_orders
  end

  def set_selected_orders(orders)
    # Use session for small selections, cache for large ones to avoid cookie overflow
    if orders.length <= 10  # Small selections in session
      session[:selected_production_orders] = orders
      # Clear cache if switching from large to small selection
      Rails.cache.delete(selection_cache_key) if session[:using_cache_storage]
      session[:using_cache_storage] = false
    else  # Large selections in cache
      session[:selected_production_orders] = nil  # Clear session
      session[:using_cache_storage] = true
      cache_key = selection_cache_key
      Rails.cache.write(cache_key, orders, expires_in: 1.hour)
    end
  end

  def broadcast_notifications(production_order)
    if production_order.company
      notification_data = {
        title: "Orden creada!",
        message: "Orden #{production_order.no_opro || production_order.order_number} para #{production_order.product.name}",
        type: "success",
        duration: 15000, # 15 seconds
        action_url: "/admin/production_orders/#{production_order.id}",
        timestamp: Time.current.iso8601
      }

      # Broadcast to company-specific channel
      broadcasting_name = "notifications:#{production_order.company.to_gid_param}"
      ActionCable.server.broadcast(
        broadcasting_name,
        {
          type: 'new_notification',
          notification: notification_data
        }
      )
    end
  end

  def set_production_order
    @production_order = ProductionOrder.find(params[:id] || params[:order_id])
  end

  def production_order_params
    params.require(:production_order).permit(
      :warehouse_id, :product_id, :quantity_requested, :quantity_produced,
      :priority, :estimated_completion, :notes, :bag_size, :bag_measurement,
      :pieces_count, :package_count, :package_measurement, :peso, :lote_referencia,
      :no_opro, :carga_copr, :ano, :mes, :fecha_completa, :company_id
    )
  end
end
