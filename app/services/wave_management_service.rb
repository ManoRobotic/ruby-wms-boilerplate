class WaveManagementService
  include StandardCrudResponses
  
  def initialize(warehouse)
    @warehouse = warehouse
  end

  # Crear wave automática basada en órdenes pendientes
  def create_auto_wave(options = {})
    strategy = options[:strategy] || 'zone_based'
    wave_type = options[:wave_type] || 'standard'
    priority = options[:priority] || 5
    max_orders = options[:max_orders] || 50
    max_items = options[:max_items] || 200

    # Obtener órdenes elegibles
    eligible_orders = get_eligible_orders(max_orders)
    return nil if eligible_orders.empty?

    # Crear wave
    wave = @warehouse.waves.create!(
      wave_type: wave_type,
      strategy: strategy,
      priority: priority,
      planned_start_time: options[:planned_start_time] || 1.hour.from_now,
      admin: options[:admin]
    )

    # Asignar órdenes usando la estrategia seleccionada
    assign_orders_to_wave(wave, eligible_orders, strategy, max_items)

    wave
  end

  # Crear wave manual con órdenes específicas
  def create_manual_wave(order_ids, options = {})
    return nil if order_ids.empty?

    orders = @warehouse.orders.where(id: order_ids, wave_id: nil)
    return nil if orders.empty?

    strategy = options[:strategy] || 'zone_based'
    wave_type = options[:wave_type] || 'standard'

    wave = @warehouse.waves.create!(
      wave_type: wave_type,
      strategy: strategy,
      priority: options[:priority] || 5,
      planned_start_time: options[:planned_start_time] || 1.hour.from_now,
      admin: options[:admin]
    )

    # Asignar todas las órdenes seleccionadas
    orders.update_all(wave_id: wave.id)
    wave.reload

    wave
  end

  # Optimizar wave existente
  def optimize_wave(wave)
    return false unless wave.planning?

    case wave.strategy
    when 'zone_based'
      optimize_by_zones(wave)
    when 'priority_based'
      optimize_by_priority(wave)
    when 'shortest_path'
      optimize_by_path(wave)
    when 'product_family'
      optimize_by_product_family(wave)
    else
      optimize_by_zones(wave) # Default
    end

    true
  end

  # Liberar wave y generar pick lists
  def release_wave(wave)
    return false unless wave.can_be_released?

    Wave.transaction do
      # Generar pick lists basadas en la estrategia
      pick_lists = generate_pick_lists_for_wave(wave)
      
      if pick_lists.any?
        wave.release!
        return pick_lists
      else
        return false
      end
    end
  rescue StandardError => e
    Rails.logger.error "Error releasing wave #{wave.id}: #{e.message}"
    false
  end

  # Obtener métricas de wave
  def wave_metrics(wave)
    {
      total_orders: wave.total_orders,
      total_items: wave.total_items,
      estimated_duration: wave.estimated_duration_minutes,
      actual_duration: wave.duration_minutes,
      completion_percentage: wave.completion_percentage,
      efficiency_score: wave.efficiency_score,
      pick_lists_count: wave.pick_lists.count,
      unique_locations: unique_locations_count(wave),
      zones_involved: zones_involved_count(wave),
      average_items_per_order: wave.total_orders > 0 ? (wave.total_items.to_f / wave.total_orders).round(2) : 0
    }
  end

  # Sugerir waves automáticas
  def suggest_waves
    suggestions = []
    
    # Wave por prioridad alta
    high_priority_orders = get_high_priority_orders
    if high_priority_orders.any?
      suggestions << {
        type: 'priority',
        description: "Wave de prioridad alta (#{high_priority_orders.count} órdenes)",
        orders: high_priority_orders,
        estimated_efficiency: calculate_efficiency_score(high_priority_orders),
        recommended_strategy: 'priority_based'
      }
    end

    # Wave por zona más activa
    zone_orders = get_orders_by_most_active_zone
    if zone_orders[:orders].any?
      suggestions << {
        type: 'zone_based',
        description: "Wave para zona #{zone_orders[:zone_name]} (#{zone_orders[:orders].count} órdenes)",
        orders: zone_orders[:orders],
        estimated_efficiency: calculate_efficiency_score(zone_orders[:orders]),
        recommended_strategy: 'zone_based'
      }
    end

    # Wave estándar balanceada
    balanced_orders = get_balanced_orders
    if balanced_orders.any?
      suggestions << {
        type: 'balanced',
        description: "Wave balanceada (#{balanced_orders.count} órdenes)",
        orders: balanced_orders,
        estimated_efficiency: calculate_efficiency_score(balanced_orders),
        recommended_strategy: 'shortest_path'
      }
    end

    suggestions
  end

  private

  def get_eligible_orders(max_orders)
    @warehouse.orders
              .where(wave_id: nil, status: ['pending', 'processing', 'confirmed'])
              .includes(:order_products, :products)
              .order(:created_at)
              .limit(max_orders)
  end

  def get_high_priority_orders
    @warehouse.orders
              .where(wave_id: nil, status: ['pending', 'processing', 'confirmed'])
              .where(priority: [1, 2, 3]) # Assuming priority field exists
              .includes(:order_products, :products)
              .limit(20)
  end

  def get_orders_by_most_active_zone
    # Find zone with most pending orders
    zone_data = @warehouse.orders
                          .joins(order_products: { product: { stocks: :location } })
                          .joins("INNER JOIN zones ON locations.zone_id = zones.id")
                          .where(wave_id: nil, status: ['pending', 'processing', 'confirmed'])
                          .group('zones.id', 'zones.name')
                          .order('COUNT(DISTINCT orders.id) DESC')
                          .limit(1)
                          .pluck('zones.name', 'COUNT(DISTINCT orders.id)')
                          .first

    if zone_data
      zone_name = zone_data[0]
      orders = @warehouse.orders
                         .joins(order_products: { product: { stocks: :location } })
                         .joins("INNER JOIN zones ON locations.zone_id = zones.id")
                         .where(wave_id: nil, status: ['pending', 'processing', 'confirmed'])
                         .where(zones: { name: zone_name })
                         .distinct
                         .limit(30)

      { zone_name: zone_name, orders: orders }
    else
      { zone_name: nil, orders: Order.none }
    end
  end

  def get_balanced_orders
    @warehouse.orders
              .where(wave_id: nil, status: ['pending', 'processing', 'confirmed'])
              .includes(:order_products, :products)
              .limit(25)
  end

  def assign_orders_to_wave(wave, orders, strategy, max_items)
    assigned_orders = []
    total_items = 0

    orders.each do |order|
      order_items = order.order_products.sum(:quantity)
      
      if total_items + order_items <= max_items
        assigned_orders << order
        total_items += order_items
      else
        break
      end
    end

    # Assign orders to wave
    assigned_orders.each { |order| order.update!(wave_id: wave.id) }
    
    # Optimize based on strategy
    optimize_wave(wave) if assigned_orders.any?
  end

  def optimize_by_zones(wave)
    # Group orders by primary zone and reorder
    orders_by_zone = wave.orders
                         .joins(order_products: { product: { stocks: :location } })
                         .joins("INNER JOIN zones ON locations.zone_id = zones.id")
                         .group_by { |order| order.order_products.first&.product&.stocks&.first&.location&.zone }
    
    # This is a simplified optimization - in production, you'd use more sophisticated algorithms
    Rails.logger.info "Optimized wave #{wave.id} by zones: #{orders_by_zone.keys.map(&:name).join(', ')}"
  end

  def optimize_by_priority(wave)
    # Orders already sorted by priority in the query
    Rails.logger.info "Optimized wave #{wave.id} by priority"
  end

  def optimize_by_path(wave)
    # This would implement actual path optimization algorithms
    # For now, just log the optimization attempt
    Rails.logger.info "Optimized wave #{wave.id} by shortest path"
  end

  def optimize_by_product_family(wave)
    # Group by product categories/families
    Rails.logger.info "Optimized wave #{wave.id} by product family"
  end

  def generate_pick_lists_for_wave(wave)
    pick_lists = []
    
    case wave.strategy
    when 'zone_based'
      pick_lists = generate_zone_based_pick_lists(wave)
    when 'priority_based'
      pick_lists = generate_priority_based_pick_lists(wave)
    else
      pick_lists = generate_standard_pick_lists(wave)
    end

    pick_lists
  end

  def generate_zone_based_pick_lists(wave)
    pick_lists = []
    
    # Group orders by zones
    zones_with_orders = wave.orders
                           .joins(order_products: { product: { stocks: :location } })
                           .joins("INNER JOIN zones ON locations.zone_id = zones.id")
                           .select('zones.*, orders.*')
                           .group_by(&:zone_id)

    zones_with_orders.each do |zone_id, zone_orders|
      zone = Zone.find(zone_id)
      
      pick_list = PickList.create!(
        admin: wave.admin,
        warehouse: wave.warehouse,
        wave: wave,
        order: zone_orders.first, # Primary order for the pick list
        pick_list_number: generate_pick_list_number(wave, zone),
        status: 'pending',
        priority: wave.priority,
        total_items: zone_orders.sum { |order| order.order_products.sum(:quantity) },
        notes: "Zone-based pick list for #{zone.name}"
      )

      pick_lists << pick_list
    end

    pick_lists
  end

  def generate_priority_based_pick_lists(wave)
    # Generate one pick list per high-priority order
    pick_lists = []
    
    wave.orders.order(priority: :asc).each do |order|
      pick_list = PickList.create!(
        admin: wave.admin,
        warehouse: wave.warehouse,
        wave: wave,
        order: order,
        pick_list_number: generate_pick_list_number(wave, order),
        status: 'pending',
        priority: order.priority || wave.priority,
        total_items: order.order_products.sum(:quantity),
        notes: "Priority-based pick list for order #{order.id}"
      )

      pick_lists << pick_list
    end

    pick_lists
  end

  def generate_standard_pick_lists(wave)
    # Generate pick lists with balanced workload
    pick_lists = []
    orders_per_list = [wave.orders.count / 3, 1].max
    order_groups = wave.orders.each_slice(orders_per_list).to_a

    order_groups.each_with_index do |orders, index|
      primary_order = orders.first
      
      pick_list = PickList.create!(
        admin: wave.admin,
        warehouse: wave.warehouse,
        wave: wave,
        order: primary_order,
        pick_list_number: generate_pick_list_number(wave, "batch_#{index + 1}"),
        status: 'pending',
        priority: wave.priority,
        total_items: orders.sum { |order| order.order_products.sum(:quantity) },
        notes: "Standard pick list batch #{index + 1}"
      )

      pick_lists << pick_list
    end

    pick_lists
  end

  def generate_pick_list_number(wave, identifier)
    timestamp = Time.current.strftime('%Y%m%d%H%M')
    "PL-#{wave.name}-#{identifier.to_s.upcase}-#{timestamp}"
  end

  def unique_locations_count(wave)
    wave.orders
        .joins(order_products: { product: { stocks: :location } })
        .select('locations.id')
        .distinct
        .count
  end

  def zones_involved_count(wave)
    wave.orders
        .joins(order_products: { product: { stocks: :location } })
        .joins("INNER JOIN zones ON locations.zone_id = zones.id")
        .select('zones.id')
        .distinct
        .count
  end

  def calculate_efficiency_score(orders)
    return 0 if orders.empty?
    
    # Simple efficiency calculation based on:
    # - Number of unique locations needed
    # - Average items per order
    # - Zone concentration
    
    total_items = orders.sum { |order| order.order_products.sum(:quantity) }
    avg_items_per_order = total_items.to_f / orders.count
    
    # Higher items per order = better efficiency
    efficiency = [avg_items_per_order * 10, 100].min
    
    efficiency.round(1)
  end
end