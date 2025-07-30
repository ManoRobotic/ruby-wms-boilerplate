class InventorySyncJob < ApplicationJob
  queue_as :default

  def perform(warehouse_id = nil)
    Rails.logger.info "Starting inventory sync job for warehouse: #{warehouse_id || 'all'}"

    warehouses = warehouse_id ? [ Warehouse.find(warehouse_id) ] : Warehouse.active.includes(:zones, :locations)

    warehouses.each do |warehouse|
      sync_warehouse_inventory(warehouse)
    end

    Rails.logger.info "Inventory sync job completed"
  end

  private

  def sync_warehouse_inventory(warehouse)
    Rails.logger.info "Syncing inventory for warehouse: #{warehouse.name}"

    # Update location utilization
    update_location_utilization(warehouse)

    # Check for low stock alerts
    check_low_stock_alerts(warehouse)

    # Update expired stock
    mark_expired_stock(warehouse)

    # Consolidate small stocks
    consolidate_small_stocks(warehouse)

    Rails.logger.info "Completed inventory sync for warehouse: #{warehouse.name}"
  end

  def update_location_utilization(warehouse)
    warehouse.locations.includes(:stocks).find_each do |location|
      current_volume = location.stocks.sum(:amount)
      location.update_column(:current_volume, current_volume) if location.current_volume != current_volume
    end
  end

  def check_low_stock_alerts(warehouse)
    low_stock_products = Product.joins(stocks: { location: { zone: :warehouse } })
                               .where(warehouses: { id: warehouse.id })
                               .group("products.id")
                               .having("SUM(stocks.amount - stocks.reserved_quantity) <= products.reorder_point")

    low_stock_products.each do |product|
      # Create replenishment task if none exists
      existing_task = Task.where(
        warehouse: warehouse,
        product: product,
        task_type: "replenishment",
        status: [ "pending", "assigned", "in_progress" ]
      ).exists?

      unless existing_task
        admin = Admin.first # Should be configurable
        Task.create!(
          admin: admin,
          warehouse: warehouse,
          product: product,
          task_type: "replenishment",
          priority: "high",
          status: "pending",
          quantity: product.reorder_point * 2,
          instructions: "Auto-generated replenishment task for low stock product: #{product.name}"
        )

        Rails.logger.info "Created replenishment task for low stock product: #{product.name}"
      end
    end
  end

  def mark_expired_stock(warehouse)
    expired_stocks = Stock.joins(location: { zone: :warehouse })
                         .where(warehouses: { id: warehouse.id })
                         .where("expiry_date < ?", Date.current)
                         .where.not(expiry_date: nil)

    expired_stocks.find_each do |stock|
      # Create adjustment transaction for expired stock
      InventoryTransaction.create!(
        warehouse: warehouse,
        location: stock.location,
        product: stock.product,
        transaction_type: "expiry",
        quantity: -stock.amount,
        admin: Admin.first,
        reason: "Expired stock - Expiry date: #{stock.expiry_date}",
        batch_number: stock.batch_number,
        size: stock.size
      )

      # Remove expired stock
      stock.destroy

      Rails.logger.info "Marked expired stock: #{stock.product.name} - #{stock.amount} units"
    end
  end

  def consolidate_small_stocks(warehouse)
    # Find products with multiple small stocks in same location
    consolidation_candidates = Stock.joins(location: { zone: :warehouse })
                                  .where(warehouses: { id: warehouse.id })
                                  .where("amount < ?", 10)
                                  .group(:product_id, :location_id, :size)
                                  .having("COUNT(*) > 1")
                                  .count

    consolidation_candidates.each do |(product_id, location_id, size), count|
      product = Product.find(product_id)
      location = Location.find(location_id)

      small_stocks = Stock.where(product: product, location: location, size: size)
                         .where("amount < ?", 10)
                         .order(:created_at)

      next if small_stocks.count <= 1

      # Consolidate into the oldest stock
      main_stock = small_stocks.first
      other_stocks = small_stocks.offset(1)

      total_amount = other_stocks.sum(:amount)

      if total_amount > 0
        main_stock.increment!(:amount, total_amount)
        other_stocks.destroy_all

        Rails.logger.info "Consolidated #{count} small stocks for #{product.name} at #{location.coordinate_code}"
      end
    end
  end
end
