class WaveProcessingJob < ApplicationJob
  queue_as :wave_processing

  def perform(wave)
    return unless wave.is_a?(Wave)
    return unless wave.ready_to_release?

    Rails.logger.info "Processing wave #{wave.id} - #{wave.name}"

    begin
      Wave.transaction do
        # Generate pick lists using the wave management service
        service = WaveManagementService.new(wave.warehouse)
        pick_lists = service.send(:generate_pick_lists_for_wave, wave)

        if pick_lists.any?
          # Generate pick list items for each pick list
          pick_lists.each do |pick_list|
            generate_pick_list_items(pick_list)
          end

          # Update wave status
          wave.update!(status: 'released')
          
          # Notify completion
          WaveNotificationJob.perform_later(wave, 'released')
          
          Rails.logger.info "Successfully processed wave #{wave.id}: #{pick_lists.count} pick lists created"
        else
          # Mark as failed if no pick lists were generated
          wave.update!(status: 'planning', notes: "Failed to generate pick lists: #{Time.current}")
          Rails.logger.error "Failed to generate pick lists for wave #{wave.id}"
        end
      end
    rescue StandardError => e
      Rails.logger.error "Error processing wave #{wave.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # Update wave with error status
      wave.update!(
        status: 'planning',
        notes: "Processing failed: #{e.message} at #{Time.current}"
      )
      
      # Notify about the error
      WaveNotificationJob.perform_later(wave, 'error', e.message)
      
      raise e
    end
  end

  private

  def generate_pick_list_items(pick_list)
    return unless pick_list.wave&.orders&.any?

    # Get all order products from orders in this wave that should be in this pick list
    order_products = if pick_list.wave.strategy == 'zone_based'
                       get_zone_based_order_products(pick_list)
                     else
                       get_standard_order_products(pick_list)
                     end

    order_products.each do |order_product|
      # Find best stock location for this product
      stock_allocation = find_best_stock_for_product(order_product.product, order_product.quantity, pick_list.warehouse)
      
      next unless stock_allocation

      # Create pick list item
      pick_list_item = pick_list.pick_list_items.create!(
        product: order_product.product,
        location: stock_allocation[:location],
        quantity_requested: order_product.quantity,
        quantity_picked: 0,
        status: 'pending',
        order_product: order_product,
        notes: "Auto-generated from wave #{pick_list.wave.name}"
      )

      # Reserve stock
      reserve_stock(stock_allocation[:stock], order_product.quantity, pick_list_item)
    end

    # Update pick list totals
    pick_list.update!(
      total_items: pick_list.pick_list_items.sum(:quantity_requested),
      picked_items: 0
    )
  end

  def get_zone_based_order_products(pick_list)
    # For zone-based strategy, get products from the specific zone
    zone = determine_pick_list_zone(pick_list)
    return OrderProduct.none unless zone

    pick_list.wave.orders
             .joins(:order_products)
             .joins("INNER JOIN products ON order_products.product_id = products.id")
             .joins("INNER JOIN stocks ON products.id = stocks.product_id")
             .joins("INNER JOIN locations ON stocks.location_id = locations.id")
             .where(locations: { zone: zone })
             .select('order_products.*')
             .distinct
  end

  def get_standard_order_products(pick_list)
    # For other strategies, distribute order products among pick lists
    if pick_list.wave.strategy == 'priority_based'
      # One order per pick list
      pick_list.order.order_products
    else
      # Multiple orders can be in one pick list - get from primary order for now
      # This could be enhanced to include multiple orders per pick list
      pick_list.order.order_products
    end
  end

  def determine_pick_list_zone(pick_list)
    # Find the primary zone for this pick list based on the order's products
    zone_counts = pick_list.order.order_products
                           .joins(product: { stocks: :location })
                           .joins("INNER JOIN zones ON locations.zone_id = zones.id")
                           .group('zones.id')
                           .count

    return nil if zone_counts.empty?

    # Return the zone with the most products
    primary_zone_id = zone_counts.max_by { |_, count| count }[0]
    Zone.find(primary_zone_id)
  end

  def find_best_stock_for_product(product, quantity_needed, warehouse)
    # Find available stock in the warehouse using FIFO strategy
    available_stocks = product.stocks
                              .joins(:location)
                              .where(locations: { zone: warehouse.zones })
                              .where('amount - reserved_quantity > 0')
                              .order(:expiry_date, :created_at)

    total_available = 0
    selected_stocks = []

    available_stocks.each do |stock|
      available_quantity = stock.amount - stock.reserved_quantity
      next if available_quantity <= 0

      needed_from_this_stock = [quantity_needed - total_available, available_quantity].min
      
      selected_stocks << {
        stock: stock,
        location: stock.location,
        quantity: needed_from_this_stock
      }
      
      total_available += needed_from_this_stock
      break if total_available >= quantity_needed
    end

    # Return the first (best) allocation if we found sufficient stock
    if total_available >= quantity_needed && selected_stocks.any?
      selected_stocks.first
    else
      Rails.logger.warn "Insufficient stock for product #{product.id}: needed #{quantity_needed}, found #{total_available}"
      nil
    end
  end

  def reserve_stock(stock, quantity, pick_list_item)
    # Reserve the stock for this pick list item
    new_reserved = stock.reserved_quantity + quantity
    
    if new_reserved <= stock.amount
      stock.update!(reserved_quantity: new_reserved)
      
      # Create inventory transaction for the reservation
      InventoryTransaction.create!(
        product: stock.product,
        location: stock.location,
        quantity: quantity,
        transaction_type: 'reservation',
        reference: pick_list_item,
        notes: "Reserved for pick list #{pick_list_item.pick_list.pick_list_number}"
      )
    else
      Rails.logger.error "Cannot reserve #{quantity} units of #{stock.product.name}: insufficient stock"
      raise "Cannot reserve stock: insufficient quantity available"
    end
  end
end