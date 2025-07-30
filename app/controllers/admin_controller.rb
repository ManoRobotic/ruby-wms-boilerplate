class AdminController < ApplicationController
  include ApiResponses

  layout "admin"
  before_action :authenticate_admin!
  before_action :ensure_admin_permissions!

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
    
    # Convert to array format for chart.js
    @revenue_by_day_chart = @revenue_by_day.map { |date, revenue| [date.to_s, revenue] }

    # Additional useful metrics
    @low_stock_products = Product.low_stock(5).limit(10) rescue []
    @best_selling_products = Product.best_selling(5) rescue []
    
    # WMS Dashboard Metrics
    @wms_metrics = calculate_wms_metrics rescue {}
    @inventory_alerts = calculate_inventory_alerts rescue {}
    @task_metrics = calculate_task_metrics rescue {}
    @pick_list_metrics = calculate_pick_list_metrics rescue {}
    @warehouse_utilization = calculate_warehouse_utilization rescue []
    @recent_transactions = InventoryTransaction.recent.limit(5) rescue []
  end

  private

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
      active_shipments: (Shipment.where(status: ['shipped', 'in_transit']).count rescue 0)
    }
  end
  
  def calculate_inventory_alerts
    {
      low_stock: Product.low_stock.count,
      overstock: (Product.overstock.count rescue 0),
      expiring_soon: (Stock.expiring_soon(30).group(:product_id).count.size rescue 0),
      expired: (Stock.expired.group(:product_id).count.size rescue 0),
      negative_stock: (Stock.where('amount < 0').count rescue 0)
    }
  end
  
  def calculate_task_metrics
    {
      pending: (Task.pending.count rescue 0),
      in_progress: (Task.in_progress.count rescue 0),
      completed_today: (Task.completed.where(completed_at: Date.current.beginning_of_day..Date.current.end_of_day).count rescue 0),
      overdue: (Task.overdue.count rescue 0),
      my_tasks: (Task.where(admin: current_admin, status: ['pending', 'assigned', 'in_progress']).count rescue 0)
    }
  end
  
  def calculate_pick_list_metrics
    {
      pending: (PickList.pending.count rescue 0),
      in_progress: (PickList.in_progress.count rescue 0),
      completed_today: (PickList.completed.where(completed_at: Date.current.beginning_of_day..Date.current.end_of_day).count rescue 0),
      overdue: (PickList.overdue.count rescue 0)
    }
  end
  
  def calculate_warehouse_utilization
    warehouses = Warehouse.active.includes(:locations)
    
    warehouses.map do |warehouse|
      {
        name: warehouse.name,
        utilization: warehouse.utilization_percentage,
        available_locations: warehouse.available_locations.count,
        total_locations: warehouse.total_locations
      }
    end
  end

  def ensure_admin_permissions!
    # Add role-based access control if needed
    # For now, just ensure admin is active
    unless current_admin&.email&.present?
      Rails.logger.warn "Unauthorized admin access attempt - Admin ID: #{current_admin&.id}, IP: #{request.remote_ip}, Path: #{request.path}"
      redirect_to root_path, alert: "Access denied"
    end
  end
end
