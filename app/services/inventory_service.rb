class InventoryService
  class InsufficientStockError < StandardError; end
  class LocationNotFoundError < StandardError; end
  class InvalidQuantityError < StandardError; end

  def self.allocate_stock(product:, quantity:, size: "standard", allocation_method: :fifo)
    new.allocate_stock(product: product, quantity: quantity, size: size, allocation_method: allocation_method)
  end

  def self.reserve_stock(product:, location:, quantity:, size: "standard", batch_number: nil)
    new.reserve_stock(product: product, location: location, quantity: quantity, size: size, batch_number: batch_number)
  end

  def self.move_stock(product:, from_location:, to_location:, quantity:, admin:, size: "standard", batch_number: nil)
    new.move_stock(product: product, from_location: from_location, to_location: to_location, quantity: quantity, admin: admin, size: size, batch_number: batch_number)
  end

  def allocate_stock(product:, quantity:, size: "standard", allocation_method: :fifo)
    raise InvalidQuantityError, "Quantity must be positive" if quantity <= 0

    available_stocks = Stock.where(product: product, size: size)
                           .joins(:location)
                           .where("stocks.amount > stocks.reserved_quantity")
                           .includes(:location)

    # Apply allocation method
    case allocation_method
    when :fifo
      available_stocks = available_stocks.order(:received_date, :created_at)
    when :lifo
      available_stocks = available_stocks.order(received_date: :desc, created_at: :desc)
    when :fefo
      available_stocks = available_stocks.order(:expiry_date, :received_date)
    end

    allocations = []
    remaining_quantity = quantity

    available_stocks.each do |stock|
      break if remaining_quantity <= 0

      allocatable_qty = [ stock.available_quantity, remaining_quantity ].min

      if allocatable_qty > 0
        allocations << {
          stock: stock,
          quantity: allocatable_qty,
          location: stock.location,
          batch_number: stock.batch_number,
          expiry_date: stock.expiry_date
        }

        remaining_quantity -= allocatable_qty
      end
    end

    {
      allocations: allocations,
      allocated_quantity: quantity - remaining_quantity,
      remaining_quantity: remaining_quantity,
      fully_allocated: remaining_quantity.zero?
    }
  end

  def reserve_stock(product:, location:, quantity:, size: "standard", batch_number: nil)
    raise InvalidQuantityError, "Quantity must be positive" if quantity <= 0

    stock = Stock.find_by(
      product: product,
      location: location,
      size: size,
      batch_number: batch_number
    )

    raise InsufficientStockError, "No stock found for product #{product.name} at #{location.coordinate_code}" unless stock

    if stock.available_quantity < quantity
      raise InsufficientStockError, "Insufficient stock. Available: #{stock.available_quantity}, Requested: #{quantity}"
    end

    stock.transaction do
      stock.increment!(:reserved_quantity, quantity)

      # Log the reservation
      Rails.logger.info "Reserved #{quantity} units of #{product.name} at #{location.coordinate_code}"

      stock
    end
  end

  def unreserve_stock(product:, location:, quantity:, size: "standard", batch_number: nil)
    stock = Stock.find_by(
      product: product,
      location: location,
      size: size,
      batch_number: batch_number
    )

    return false unless stock && stock.reserved_quantity >= quantity

    stock.transaction do
      stock.decrement!(:reserved_quantity, quantity)

      Rails.logger.info "Unreserved #{quantity} units of #{product.name} at #{location.coordinate_code}"

      stock
    end
  end

  def move_stock(product:, from_location:, to_location:, quantity:, admin:, size: "standard", batch_number: nil)
    raise InvalidQuantityError, "Quantity must be positive" if quantity <= 0
    raise LocationNotFoundError, "From location is required" unless from_location
    raise LocationNotFoundError, "To location is required" unless to_location

    from_stock = Stock.find_by(
      product: product,
      location: from_location,
      size: size,
      batch_number: batch_number
    )

    raise InsufficientStockError, "No stock found at source location" unless from_stock
    raise InsufficientStockError, "Insufficient available stock" if from_stock.available_quantity < quantity

    Stock.transaction do
      # Remove from source location
      new_from_amount = from_stock.amount - quantity

      if new_from_amount <= 0
        unit_cost = from_stock.unit_cost
        expiry_date = from_stock.expiry_date
        from_stock.destroy
      else
        unit_cost = from_stock.unit_cost
        expiry_date = from_stock.expiry_date
        from_stock.update!(amount: new_from_amount)
      end

      # Add to destination location
      to_stock = Stock.find_or_initialize_by(
        product: product,
        location: to_location,
        size: size,
        batch_number: batch_number
      )

      if to_stock.persisted?
        to_stock.increment!(:amount, quantity)
      else
        to_stock.assign_attributes(
          amount: quantity,
          unit_cost: unit_cost,
          expiry_date: expiry_date,
          received_date: Date.current
        )
        to_stock.save!
      end

      # Create inventory transactions
      InventoryTransaction.create!([
        {
          warehouse: from_location.warehouse,
          location: from_location,
          product: product,
          transaction_type: "move",
          quantity: -quantity,
          unit_cost: unit_cost,
          admin: admin,
          reason: "Moved to #{to_location.coordinate_code}",
          batch_number: batch_number,
          size: size
        },
        {
          warehouse: to_location.warehouse,
          location: to_location,
          product: product,
          transaction_type: "move",
          quantity: quantity,
          unit_cost: unit_cost,
          admin: admin,
          reason: "Moved from #{from_location.coordinate_code}",
          batch_number: batch_number,
          size: size
        }
      ])

      {
        from_stock: from_stock,
        to_stock: to_stock,
        quantity_moved: quantity
      }
    end
  end

  def adjust_stock(product:, location:, quantity:, admin:, reason:, size: "standard", batch_number: nil)
    raise InvalidQuantityError, "Quantity cannot be zero" if quantity == 0

    stock = Stock.find_or_initialize_by(
      product: product,
      location: location,
      size: size,
      batch_number: batch_number
    )

    Stock.transaction do
      if stock.persisted?
        new_amount = stock.amount + quantity

        if new_amount < 0
          raise InsufficientStockError, "Adjustment would result in negative stock"
        elsif new_amount == 0
          stock.destroy
        else
          stock.update!(amount: new_amount)
        end
      elsif quantity > 0
        stock.assign_attributes(
          amount: quantity,
          unit_cost: product.price * 0.6, # Default cost
          received_date: Date.current
        )
        stock.save!
      else
        raise InsufficientStockError, "Cannot create negative stock"
      end

      # Create transaction record
      transaction_type = quantity > 0 ? "adjustment_in" : "adjustment_out"

      InventoryTransaction.create!(
        warehouse: location.warehouse,
        location: location,
        product: product,
        transaction_type: transaction_type,
        quantity: quantity,
        admin: admin,
        reason: reason,
        batch_number: batch_number,
        size: size
      )

      stock
    end
  end

  def check_stock_availability(product:, quantity:, size: "standard")
    total_available = Stock.where(product: product, size: size)
                          .sum("amount - reserved_quantity")

    {
      available: total_available >= quantity,
      total_available: total_available,
      shortage: quantity > total_available ? quantity - total_available : 0
    }
  end

  def get_stock_summary(product:, warehouse: nil)
    query = Stock.joins(location: { zone: :warehouse })
               .where(product: product)

    query = query.where(warehouses: { id: warehouse }) if warehouse

    {
      total_stock: query.sum(:amount),
      reserved_stock: query.sum(:reserved_quantity),
      available_stock: query.sum("amount - reserved_quantity"),
      locations_count: query.distinct.count(:location_id),
      batches_count: query.where.not(batch_number: nil).distinct.count(:batch_number)
    }
  end

  def find_optimal_pick_locations(product:, quantity:, size: "standard", warehouse: nil)
    query = Stock.joins(location: { zone: :warehouse })
               .where(product: product, size: size)
               .where("stocks.amount > stocks.reserved_quantity")
               .includes(:location)

    query = query.where(warehouses: { id: warehouse }) if warehouse

    # Prioritize picking zones, then by accessibility
    locations = query.joins(location: :zone)
                    .order(
                      Arel.sql("CASE WHEN zones.zone_type = 'picking' THEN 1 ELSE 2 END"),
                      "stocks.expiry_date ASC NULLS LAST",
                      "stocks.amount DESC"
                    )

    pick_plan = []
    remaining_quantity = quantity

    locations.each do |stock|
      break if remaining_quantity <= 0

      pickable_qty = [ stock.available_quantity, remaining_quantity ].min

      if pickable_qty > 0
        pick_plan << {
          location: stock.location,
          stock: stock,
          quantity: pickable_qty,
          batch_number: stock.batch_number,
          expiry_date: stock.expiry_date
        }

        remaining_quantity -= pickable_qty
      end
    end

    {
      pick_plan: pick_plan,
      total_planned: quantity - remaining_quantity,
      remaining_needed: remaining_quantity,
      fully_planned: remaining_quantity.zero?
    }
  end
end
