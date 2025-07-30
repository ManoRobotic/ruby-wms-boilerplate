class PickListService
  class InsufficientStockError < StandardError; end
  class InvalidOrderError < StandardError; end

  def self.generate_pick_list(order:, admin:, warehouse: nil)
    new.generate_pick_list(order: order, admin: admin, warehouse: warehouse)
  end

  def self.optimize_pick_route(pick_list:)
    new.optimize_pick_route(pick_list: pick_list)
  end

  def self.process_pick(pick_list_item:, quantity_picked:, admin:)
    new.process_pick(pick_list_item: pick_list_item, quantity_picked: quantity_picked, admin: admin)
  end

  def generate_pick_list(order:, admin:, warehouse: nil)
    raise InvalidOrderError, "Order must be a sales order" unless order.sales_order?
    raise InvalidOrderError, "Order already has an active pick list" if order.pick_lists.active.exists?

    warehouse ||= order.warehouse || Warehouse.main_warehouse
    raise InvalidOrderError, "No warehouse specified" unless warehouse

    PickList.transaction do
      pick_list = PickList.create!(
        order: order,
        admin: admin,
        warehouse: warehouse,
        priority: order.priority || "medium",
        status: "pending"
      )

      # Generate pick list items
      sequence = 1
      total_items = 0
      insufficient_items = []

      order.order_products.includes(:product).each do |order_product|
        # Find optimal locations for picking
        pick_plan = InventoryService.new.find_optimal_pick_locations(
          product: order_product.product,
          quantity: order_product.quantity,
          size: order_product.size,
          warehouse: warehouse
        )

        if pick_plan[:fully_planned]
          pick_plan[:pick_plan].each do |plan|
            pick_list.pick_list_items.create!(
              product: order_product.product,
              location: plan[:location],
              quantity_requested: plan[:quantity],
              size: order_product.size,
              sequence: sequence,
              status: "pending"
            )

            # Reserve the stock
            InventoryService.new.reserve_stock(
              product: order_product.product,
              location: plan[:location],
              quantity: plan[:quantity],
              size: order_product.size,
              batch_number: plan[:batch_number]
            )

            total_items += plan[:quantity]
            sequence += 1
          end
        else
          insufficient_items << {
            product: order_product.product,
            requested: order_product.quantity,
            available: pick_plan[:total_planned]
          }
        end
      end

      if insufficient_items.any?
        # Rollback and raise error
        raise InsufficientStockError, "Insufficient stock for items: #{insufficient_items.map { |i| i[:product].name }.join(', ')}"
      end

      # Update pick list totals
      pick_list.update!(total_items: total_items)

      # Optimize the route
      optimize_pick_route(pick_list: pick_list)

      pick_list
    end
  end

  def optimize_pick_route(pick_list:)
    # Optimize by zone -> aisle -> bay -> level
    items = pick_list.pick_list_items.includes(location: :zone)

    optimized_items = items.sort_by do |item|
      location = item.location
      [
        zone_priority(location.zone.zone_type),
        location.aisle.to_i,
        location.bay.to_i,
        location.level.to_i
      ]
    end

    # Update sequence numbers
    optimized_items.each_with_index do |item, index|
      item.update_column(:sequence, index + 1)
    end

    pick_list.reload
  end

  def process_pick(pick_list_item:, quantity_picked:, admin:)
    raise ArgumentError, "Quantity picked cannot be negative" if quantity_picked < 0
    raise ArgumentError, "Quantity picked exceeds requested" if quantity_picked > pick_list_item.quantity_requested

    PickListItem.transaction do
      pick_list_item.update!(
        quantity_picked: quantity_picked,
        status: determine_item_status(pick_list_item.quantity_requested, quantity_picked)
      )

      if quantity_picked > 0
        # Process the stock movement
        stock = Stock.find_by(
          product: pick_list_item.product,
          location: pick_list_item.location,
          size: pick_list_item.size
        )

        if stock
          # Consume reserved stock
          if stock.reserved_quantity >= quantity_picked
            stock.decrement!(:reserved_quantity, quantity_picked)
            stock.decrement!(:amount, quantity_picked)

            # Remove stock record if amount reaches zero
            stock.destroy if stock.amount <= 0

            # Create inventory transaction
            InventoryTransaction.create!(
              warehouse: pick_list_item.location.warehouse,
              location: pick_list_item.location,
              product: pick_list_item.product,
              transaction_type: "pick",
              quantity: -quantity_picked,
              admin: admin,
              reference: pick_list_item.pick_list,
              reason: "Picked for order #{pick_list_item.pick_list.order.display_number}",
              size: pick_list_item.size
            )
          end
        end

        # Unreserve any remaining quantity
        shortage = pick_list_item.quantity_requested - quantity_picked
        if shortage > 0
          InventoryService.new.unreserve_stock(
            product: pick_list_item.product,
            location: pick_list_item.location,
            quantity: shortage,
            size: pick_list_item.size
          )
        end
      else
        # If nothing was picked, unreserve all
        InventoryService.new.unreserve_stock(
          product: pick_list_item.product,
          location: pick_list_item.location,
          quantity: pick_list_item.quantity_requested,
          size: pick_list_item.size
        )
      end

      # Update pick list progress
      update_pick_list_progress(pick_list_item.pick_list)

      pick_list_item
    end
  end

  def complete_pick_list(pick_list:, admin:)
    raise ArgumentError, "Pick list is not in progress" unless pick_list.in_progress?

    incomplete_items = pick_list.pick_list_items.where(status: "pending")

    if incomplete_items.exists?
      raise ArgumentError, "Cannot complete pick list with pending items"
    end

    PickList.transaction do
      pick_list.update!(
        status: "completed",
        completed_at: Time.current
      )

      # Update order status
      order = pick_list.order
      order.update!(fulfillment_status: "picked")

      # Create tasks for picked items (optional)
      create_putaway_tasks_for_picked_items(pick_list, admin)

      pick_list
    end
  end

  def cancel_pick_list(pick_list:, reason: nil)
    PickList.transaction do
      # Unreserve all stock
      pick_list.pick_list_items.each do |item|
        next if item.quantity_picked >= item.quantity_requested

        unreserve_quantity = item.quantity_requested - item.quantity_picked

        InventoryService.new.unreserve_stock(
          product: item.product,
          location: item.location,
          quantity: unreserve_quantity,
          size: item.size
        )
      end

      # Update statuses
      pick_list.pick_list_items.update_all(status: "cancelled")
      pick_list.update!(
        status: "cancelled",
        completed_at: Time.current
      )

      pick_list
    end
  end

  def get_pick_list_metrics(date_range = 30.days.ago..Time.current)
    pick_lists = PickList.where(created_at: date_range)

    {
      total_pick_lists: pick_lists.count,
      completed_pick_lists: pick_lists.completed.count,
      average_completion_time: calculate_average_completion_time(pick_lists.completed),
      pick_accuracy: calculate_pick_accuracy(pick_lists.completed),
      total_items_picked: pick_lists.joins(:pick_list_items).sum("pick_list_items.quantity_picked"),
      productivity_per_hour: calculate_productivity_per_hour(pick_lists.completed)
    }
  end

  private

  def zone_priority(zone_type)
    case zone_type
    when "picking" then 1
    when "storage" then 2
    when "receiving" then 3
    else 4
    end
  end

  def determine_item_status(quantity_requested, quantity_picked)
    if quantity_picked == 0
      "pending"
    elsif quantity_picked >= quantity_requested
      "picked"
    else
      "short_picked"
    end
  end

  def update_pick_list_progress(pick_list)
    total_requested = pick_list.pick_list_items.sum(:quantity_requested)
    total_picked = pick_list.pick_list_items.sum(:quantity_picked)

    pick_list.update_columns(
      total_items: total_requested,
      picked_items: total_picked
    )

    # Auto-complete if all items are processed
    if pick_list.pending? || pick_list.in_progress?
      pending_items = pick_list.pick_list_items.where(status: "pending").count

      if pending_items == 0
        pick_list.update!(status: "completed", completed_at: Time.current)
        pick_list.order.update!(fulfillment_status: "picked")
      elsif pick_list.pending?
        pick_list.update!(status: "in_progress", started_at: Time.current)
      end
    end
  end

  def create_putaway_tasks_for_picked_items(pick_list, admin)
    # This could create tasks to put picked items into a staging area
    # Implementation depends on warehouse workflow
  end

  def calculate_average_completion_time(completed_pick_lists)
    times = completed_pick_lists.where.not(started_at: nil, completed_at: nil)
                               .pluck(:started_at, :completed_at)
                               .map { |start, finish| finish - start }

    return 0 if times.empty?

    times.sum / times.size
  end

  def calculate_pick_accuracy(completed_pick_lists)
    items = PickListItem.joins(:pick_list)
                       .where(pick_lists: { id: completed_pick_lists.select(:id) })

    total_items = items.count
    return 0 if total_items == 0

    accurate_items = items.where("quantity_picked = quantity_requested").count

    (accurate_items.to_f / total_items * 100).round(2)
  end

  def calculate_productivity_per_hour(completed_pick_lists)
    total_items = completed_pick_lists.joins(:pick_list_items)
                                    .sum("pick_list_items.quantity_picked")

    total_hours = completed_pick_lists.where.not(started_at: nil, completed_at: nil)
                                    .sum("EXTRACT(EPOCH FROM (completed_at - started_at)) / 3600")

    return 0 if total_hours == 0

    (total_items / total_hours).round(2)
  end
end
