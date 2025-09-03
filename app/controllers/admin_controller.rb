class AdminController < ApplicationController
  include ApiResponses
  include NotificationManagement

  layout "admin"

  # Solo permitir acceso a admins reales o usuarios con rol admin/supervisor
  before_action :authenticate_admin_or_privileged_user!
  before_action :ensure_admin_permissions!

  helper_method :sort_column, :sort_direction

  def index
    # Use new Order scopes and methods for better performance
    @recent_orders = Order.pending.recent.limit(5)
    @orders = @recent_orders # For backward compatibility with the view

    # Cache expensive calculations
    @quick_stats = Rails.cache.fetch("admin_quick_stats_#{Date.current}", expires_in: 1.hour) do
      calculate_quick_stats
    end

    @revenue_by_day = Rails.cache.fetch("admin_revenue_by_day_#{Date.current}", expires_in: 1.hour) do
      Order.revenue_by_day(7)
    end

    # Convert to array format for chart.js - ensure we always have data
    @revenue_by_day_chart = if @revenue_by_day && @revenue_by_day.any?
      @revenue_by_day.map { |date, revenue| [ date.to_s, revenue || 0 ] }
    else
      # Generate default data with zeros for the last 7 days
      (6.days.ago.to_date..Date.current).map { |date| [ date.to_s, 0 ] }
    end

    # Additional useful metrics
    @low_stock_products = Product.low_stock(5).limit(10) rescue []
    @best_selling_products = Product.best_selling(5) rescue []

    # WMS Dashboard Metrics
    @wms_metrics = calculate_wms_metrics rescue {}
    @inventory_alerts = calculate_inventory_alerts rescue {}
    @task_metrics = calculate_task_metrics rescue {}
    @pick_list_metrics = calculate_pick_list_metrics rescue {}
    @warehouse_utilization = calculate_warehouse_utilization rescue []
    # Filter recent transactions by user's warehouse if not admin or operador
    transactions_scope = InventoryTransaction.recent
    if current_user && current_user.warehouse_id.present? && !current_user.admin? && !current_user.operador?
      transactions_scope = transactions_scope.joins(location: :zone).where(zones: { warehouse_id: current_user.warehouse_id })
    end
    @recent_transactions = transactions_scope.limit(5) rescue []
  end

  private

  def sortable_columns
    []
  end

  def sort_column
    sortable_columns.include?(params[:column]) ? params[:column] : "created_at"
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : "desc"
  end

  def calculate_quick_stats
    today_start = Time.current.beginning_of_day
    today_end = Time.current.end_of_day

    today_orders_count = Order.count_for_period(today_start, today_end)
    today_revenue = Order.revenue_for_period(today_start, today_end)
    today_avg = Order.average_order_value_for_period(today_start, today_end)

    # Average items per order today
    per_sale = if today_orders_count > 0
      OrderProduct.joins(:order)
                  .where(orders: { created_at: today_start..today_end })
                  .average(:quantity)
    else
      0
    end

    {
      sales: today_orders_count,
      revenue: today_revenue > 0 ? today_revenue : nil,
      avg_sale: today_avg,
      per_sale: per_sale
    }
  end

  def calculate_wms_metrics
    {
      total_warehouses: Warehouse.active.count,
      total_locations: Location.active.count,
      total_products: Product.active.count,
      total_inventory_value: Product.inventory_valuation || 0,
      low_stock_products: Product.low_stock.count,
      pending_receipts: (Receipt.scheduled.count rescue 0),
      active_shipments: (Shipment.where(status: [ "shipped", "in_transit" ]).count rescue 0)
    }
  end

  def calculate_inventory_alerts
    {
      low_stock: Product.low_stock.count,
      overstock: (Product.overstock.count rescue 0),
      expiring_soon: (Stock.expiring_soon(30).group(:product_id).count.size rescue 0),
      expired: (Stock.expired.group(:product_id).count.size rescue 0),
      negative_stock: (Stock.where("amount < 0").count rescue 0)
    }
  end

  def calculate_task_metrics
    base_scope = Task

    # Filter by warehouse if user is not admin or operador
    if current_user && current_user.warehouse_id.present? && !current_user.admin? && !current_user.operador?
      base_scope = base_scope.where(warehouse_id: current_user.warehouse_id)
    end

    {
      pending: (base_scope.pending.count rescue 0),
      in_progress: (base_scope.in_progress.count rescue 0),
      completed_today: (base_scope.completed.where(completed_at: Date.current.beginning_of_day..Date.current.end_of_day).count rescue 0),
      overdue: (base_scope.overdue.count rescue 0),
      my_tasks: (current_user ? base_scope.where(admin: current_user, status: [ "pending", "assigned", "in_progress" ]).count : 0 rescue 0)
    }
  end

  def calculate_pick_list_metrics
    base_scope = PickList

    # Filter by warehouse if user is not admin or operador
    if current_user && current_user.warehouse_id.present? && !current_user.admin? && !current_user.operador?
      base_scope = base_scope.where(warehouse_id: current_user.warehouse_id)
    end

    {
      pending: (base_scope.pending.count rescue 0),
      in_progress: (base_scope.in_progress.count rescue 0),
      completed_today: (base_scope.completed.where(completed_at: Date.current.beginning_of_day..Date.current.end_of_day).count rescue 0),
      overdue: (base_scope.overdue.count rescue 0)
    }
  end

  def calculate_warehouse_utilization
    warehouses = Warehouse.active.includes(:locations)

    # Filter by user's warehouse if not admin or operador
    if current_user && current_user.warehouse_id.present? && !current_user.admin? && !current_user.operador?
      warehouses = warehouses.where(id: current_user.warehouse_id)
    end

    warehouses.map do |warehouse|
      {
        name: warehouse.name,
        utilization: warehouse.utilization_percentage,
        available_locations: warehouse.available_locations.count,
        total_locations: warehouse.total_locations
      }
    end
  end

  def authenticate_admin_or_privileged_user!
    unless current_admin || (current_user&.admin? || current_user&.supervisor? || current_user&.operador?)
      redirect_to new_user_session_path, alert: "Necesitas permisos de administrador para acceder."
    end
  end

  def ensure_admin_permissions!
    # Para admins reales, verificar que tengan email válido y estén activos
    if current_admin
      if current_admin.email.blank? || !current_admin.persisted?
        Rails.logger.warn "Unauthorized admin access attempt - Admin ID: #{current_admin&.id}, Email: #{current_admin&.email}, IP: #{request.remote_ip}, Path: #{request.path}"
        sign_out current_admin
        redirect_to new_admin_session_path, alert: "Sesión inválida. Por favor, inicia sesión nuevamente."
        return
      end
    end

    # Para usuarios, verificar permisos específicos
    if current_user && !current_user.can?("read_admin_dashboard")
      redirect_to root_path, alert: "No tienes permisos para acceder al panel de administración."
    end
  end
end
