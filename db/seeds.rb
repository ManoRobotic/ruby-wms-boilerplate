# Clear existing data
puts "🗑️  Clearing existing data..."
begin
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE pick_list_items RESTART IDENTITY CASCADE") rescue nil
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE pick_lists RESTART IDENTITY CASCADE") rescue nil
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE receipt_items RESTART IDENTITY CASCADE") rescue nil
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE receipts RESTART IDENTITY CASCADE") rescue nil
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE cycle_count_items RESTART IDENTITY CASCADE") rescue nil
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE cycle_counts RESTART IDENTITY CASCADE") rescue nil
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE shipments RESTART IDENTITY CASCADE") rescue nil
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE tasks RESTART IDENTITY CASCADE") rescue nil
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE inventory_transactions RESTART IDENTITY CASCADE") rescue nil
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE stocks RESTART IDENTITY CASCADE") rescue nil
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE locations RESTART IDENTITY CASCADE") rescue nil
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE zones RESTART IDENTITY CASCADE") rescue nil
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE warehouses RESTART IDENTITY CASCADE") rescue nil
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE order_products RESTART IDENTITY CASCADE") rescue nil
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE orders RESTART IDENTITY CASCADE") rescue nil
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE products RESTART IDENTITY CASCADE") rescue nil
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE categories RESTART IDENTITY CASCADE") rescue nil
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE admins RESTART IDENTITY CASCADE") rescue nil
rescue => e
  puts "Error clearing data: #{e.message}"
  # Fallback to regular destroy_all
  Order.destroy_all
  Product.destroy_all
  Category.destroy_all
  Admin.destroy_all
end

puts "👤 Creating admin user..."
admin = Admin.create!(
  email: "admin@wmsapp.com",
  password: "password123",
  password_confirmation: "password123",
  name: "Super Admin",
  address: "Guadalajara, México"
)
puts "✅ Admin created: #{admin.email}"

puts "📂 Creating categories..."
categories = Category.create!([
  {
    name: "Monedas de Oro",
    description: "Monedas de oro mexicanas e internacionales. Perfectas para inversión y colección.",
    image_url: "https://www.banxico.org.mx/multimedia/rev_1kg_oro_big.png"
  },
  {
    name: "Monedas de Plata",
    description: "Monedas de plata pura .999 con diseños históricos mexicanos.",
    image_url: "https://www.banxico.org.mx/multimedia/quijoteanv.png"
  },
  {
    name: "Numismática",
    description: "Monedas históricas y de colección con valor numismático especial.",
    image_url: "https://www.banxico.org.mx/multimedia/busto.png"
  },
  {
    name: "Billetes Históricos",
    description: "Billetes históricos mexicanos y extranjeros para coleccionistas.",
    image_url: "https://www.banxico.org.mx/multimedia/famG_tamanio_reducido.png"
  },
  {
    name: "Lingotes",
    description: "Lingotes de oro y plata pura para inversión.",
    image_url: "https://www.banxico.org.mx/multimedia/lingote_oro.png"
  },
  {
    name: "Joyería",
    description: "Joyería en metales preciosos con diseños exclusivos.",
    image_url: "https://www.banxico.org.mx/multimedia/joyeria.png"
  }
])
puts "✅ Created #{categories.count} categories"

puts "🪙 Creating products..."

# Monedas de Oro
oro_category = categories.find { |c| c.name == "Monedas de Oro" }
oro_products = Product.create!([
  {
    name: "Centenario Oro 50 Pesos",
    description: "Moneda de oro puro .900 de 50 pesos mexicanos. Diseño clásico del Centenario con el Ángel de la Independencia.",
    price: 65000,
    category: oro_category,
    active: true,
    image_url: "https://www.banxico.org.mx/multimedia/rev_1kg_oro_big.png"
  },
  {
    name: "Centenario Oro 20 Pesos",
    description: "Moneda de oro .900 de 20 pesos. Perfecta para iniciar tu colección de oro mexicano.",
    price: 26000,
    category: oro_category,
    active: true,
    image_url: "https://www.banxico.org.mx/multimedia/centenario_20_pesos.png"
  },
  {
    name: "Centenario Oro 10 Pesos",
    description: "Moneda de oro de 10 pesos mexicanos. Ideal para regalos e inversión pequeña.",
    price: 13000,
    category: oro_category,
    active: true,
    image_url: "https://www.banxico.org.mx/multimedia/centenario_10_pesos.png"
  },
  {
    name: "Centenario Oro 5 Pesos",
    description: "La moneda de oro más pequeña de la serie Centenario. Perfecta para coleccionistas.",
    price: 6500,
    category: oro_category,
    active: true,
    image_url: "https://www.banxico.org.mx/multimedia/centenario_5_pesos.png"
  }
])

# Monedas de Plata
plata_category = categories.find { |c| c.name == "Monedas de Plata" }
plata_products = Product.create!([
  {
    name: "Libertad Plata 1 Onza",
    description: "Moneda de plata pura .999 de 1 onza. La moneda oficial de inversión de México.",
    price: 850,
    category: plata_category,
    active: true,
    image_url: "https://www.banxico.org.mx/multimedia/libertad_plata_1oz.png"
  },
  {
    name: "Libertad Plata 1/2 Onza",
    description: "Media onza de plata pura con el diseño icónico de la Victoria Alada.",
    price: 450,
    category: plata_category,
    active: true,
    image_url: "https://www.banxico.org.mx/multimedia/libertad_plata_half.png"
  },
  {
    name: "Libertad Plata 1/4 Onza",
    description: "Cuarto de onza de plata pura .999. Perfecta para iniciar tu colección.",
    price: 250,
    category: plata_category,
    active: true,
    image_url: "https://www.banxico.org.mx/multimedia/libertad_plata_quarter.png"
  },
  {
    name: "Libertad Plata 1/10 Onza",
    description: "La moneda de plata más pequeña de la serie Libertad.",
    price: 120,
    category: plata_category,
    active: true,
    image_url: "https://www.banxico.org.mx/multimedia/libertad_plata_tenth.png"
  }
])

# Numismática
numismatica_category = categories.find { |c| c.name == "Numismática" }
numismatica_products = Product.create!([
  {
    name: "Hidalgo 8 Reales 1821",
    description: "Moneda histórica de plata del período de independencia. Pieza de gran valor numismático.",
    price: 15000,
    category: numismatica_category,
    active: true,
    image_url: "https://www.banxico.org.mx/multimedia/hidalgo_8_reales.png"
  },
  {
    name: "Águila Mexicana 1863",
    description: "Moneda del Segundo Imperio Mexicano. Pieza histórica de gran rareza.",
    price: 25000,
    category: numismatica_category,
    active: true,
    image_url: "https://www.banxico.org.mx/multimedia/aguila_1863.png"
  },
  {
    name: "Peso Fuerte 1898",
    description: "Moneda de plata del Porfiriato. Excelente estado de conservación.",
    price: 3500,
    category: numismatica_category,
    active: true,
    image_url: "https://www.banxico.org.mx/multimedia/peso_fuerte_1898.png"
  }
])

# Billetes Históricos
billetes_category = categories.find { |c| c.name == "Billetes Históricos" }
billetes_products = Product.create!([
  {
    name: "Billete 500 Pesos 1983",
    description: "Billete histórico mexicano con la imagen de Francisco I. Madero.",
    price: 150,
    category: billetes_category,
    active: true,
    image_url: "https://www.banxico.org.mx/multimedia/billete_500_madero.png"
  },
  {
    name: "Billete 1000 Pesos 1985",
    description: "Billete conmemorativo con Juana de Asbaje (Sor Juana Inés de la Cruz).",
    price: 200,
    category: billetes_category,
    active: true,
    image_url: "https://www.banxico.org.mx/multimedia/billete_1000_sorjuana.png"
  }
])

# Lingotes
lingotes_category = categories.find { |c| c.name == "Lingotes" }
lingotes_products = Product.create!([
  {
    name: "Lingote Oro 10 Gramos",
    description: "Lingote de oro puro .999 de 10 gramos. Perfecto para inversión.",
    price: 8500,
    category: lingotes_category,
    active: true,
    image_url: "https://www.banxico.org.mx/multimedia/lingote_oro_10g.png"
  },
  {
    name: "Lingote Plata 1 Onza",
    description: "Lingote de plata pura .999 de 1 onza troy.",
    price: 750,
    category: lingotes_category,
    active: true,
    image_url: "https://www.banxico.org.mx/multimedia/lingote_plata_1oz.png"
  }
])

all_products = oro_products + plata_products + numismatica_products + billetes_products + lingotes_products
puts "✅ Created #{all_products.count} products"

puts "📦 Creating stock entries..."
stock_count = 0
all_products.each do |product|
  # Create varied stock levels
  stock_amount = case product.category.name
  when "Monedas de Oro"
    rand(5..15)  # Oro tiene menos stock
  when "Monedas de Plata"
    rand(20..50) # Plata tiene más stock
  when "Numismática"
    rand(1..5)   # Numismática es muy limitada
  when "Billetes Históricos"
    rand(3..10)  # Billetes moderado stock
  else
    rand(10..30) # Otros productos
  end

  Stock.create!(
    product: product,
    amount: stock_amount,
    size: "standard"
  )
  stock_count += 1
end
puts "✅ Created #{stock_count} stock entries"

puts "📈 Creating sample orders..."
# Create some sample orders with different statuses
sample_orders = []

# Recent completed orders
3.times do |i|
  order = Order.create!(
    customer_email: "cliente#{i+1}@example.com",
    total: rand(1000..50000),
    address: "Dirección #{i+1}, Ciudad de México, México",
    status: :delivered,
    fulfilled: true,
    payment_id: "MP-sample-#{SecureRandom.hex(8)}",
    created_at: rand(1..7).days.ago
  )

  # Add order products
  selected_products = all_products.sample(rand(1..3))
  selected_products.each do |product|
    quantity = rand(1..2)
    OrderProduct.create!(
      order: order,
      product: product,
      quantity: quantity,
      unit_price: product.price,
      size: "standard"
    )
  end

  sample_orders << order
end

# Pending orders
2.times do |i|
  order = Order.create!(
    customer_email: "pendiente#{i+1}@example.com",
    total: rand(500..15000),
    address: "Dirección Pendiente #{i+1}, Guadalajara, México",
    status: :pending,
    fulfilled: false,
    payment_id: "MP-pending-#{SecureRandom.hex(8)}",
    created_at: rand(1..3).days.ago
  )

  # Add order products
  selected_products = all_products.sample(rand(1..2))
  selected_products.each do |product|
    quantity = 1
    OrderProduct.create!(
      order: order,
      product: product,
      quantity: quantity,
      unit_price: product.price,
      size: "standard"
    )
  end

  sample_orders << order
end

puts "✅ Created #{sample_orders.count} sample orders"

puts "🎯 Seeds summary:"
puts "  📂 Categories: #{Category.count}"
puts "  🪙 Products: #{Product.count}"
puts "  📦 Stock entries: #{Stock.count}"
puts "  👤 Admins: #{Admin.count}"
puts "  📋 Orders: #{Order.count}"
puts "  🛒 Order products: #{OrderProduct.count}"
puts ""
puts "🔐 Admin credentials:"
puts "  Email: admin@wmsapp.com"
puts "  Password: password123"
puts ""
puts "✅ Database seeded successfully! 🚀"

# WMS SPECIFIC SEEDING
puts ""
puts "🏭 Starting WMS-specific seeding..."

# Create warehouses with the existing admin
if Warehouse.count.zero?
  warehouses_data = [
    {
      name: 'Centro de Distribución Principal',
      code: 'CDP01',
      address: 'Av. Industrial 1234, Zona Industrial, CDMX 12345',
      active: true,
      contact_info: {
        phone: '+52-55-1234-5678',
        email: 'cdp@wmsapp.com',
        manager: 'Carlos Rodríguez',
        hours: '24/7'
      }
    },
    {
      name: 'Almacén Regional Norte',
      code: 'ARN01',
      address: 'Blvd. Norte 5678, Monterrey, NL 67890',
      active: true,
      contact_info: {
        phone: '+52-81-9876-5432',
        email: 'arn@wmsapp.com',
        manager: 'María López',
        hours: 'Lun-Vie 8AM-6PM'
      }
    }
  ]

  warehouses_data.each do |wh_data|
    warehouse = Warehouse.create!(
      name: wh_data[:name],
      code: wh_data[:code],
      address: wh_data[:address],
      active: wh_data[:active],
      contact_info: wh_data[:contact_info]
    )
    puts "✅ Created warehouse: #{warehouse.name}"
  end
end

# Create zones for each warehouse
if Zone.count.zero?
  zone_types = [ 'receiving', 'storage', 'picking', 'packing', 'shipping' ]

  Warehouse.find_each do |warehouse|
    zone_types.each_with_index do |zone_type, index|
      zone = warehouse.zones.create!(
        name: "Zona #{zone_type.titleize} #{index + 1}",
        code: "#{zone_type.upcase[0..2]}#{index + 1}",
        zone_type: zone_type,
        description: "Área de operaciones de #{zone_type.titleize}"
      )
      puts "✅ Created zone: #{zone.name} in #{warehouse.name}"
    end
  end
end

# Create locations in storage zones
if Location.count.zero?
  Zone.where(zone_type: 'storage').find_each do |zone|
    (1..3).each do |aisle| # Reduced for demo
      (1..5).each do |bay|  # Reduced for demo
        (1..3).each do |level| # Reduced for demo
          location = zone.locations.create!(
            aisle: aisle.to_s.rjust(2, '0'),
            bay: bay.to_s.rjust(2, '0'),
            level: level.to_s,
            position: '01',
            location_type: 'bin',
            capacity: 100,
            barcode: "#{zone.warehouse.code}-#{zone.code}-#{aisle.to_s.rjust(2, '0')}-#{bay.to_s.rjust(2, '0')}-#{level}",
            active: true
          )
        end
      end
    end
    puts "✅ Created locations for zone: #{zone.name}"
  end
end

# Update existing products with WMS fields
Product.where(sku: nil).find_each.with_index do |product, index|
  product.update!(
    sku: "#{product.name.gsub(/[^a-zA-Z0-9]/, '').upcase[0..5]}#{(index + 1).to_s.rjust(3, '0')}",
    weight: case product.category.name
            when 'Monedas de Oro', 'Monedas de Plata'
             rand(0.02..0.05) # 20-50 gramos
            when 'Lingotes'
             rand(0.01..1.0) # 10g - 1kg
            else
             rand(0.01..0.1) # Billetes y otros
            end,
    dimensions: { length: rand(2..5), width: rand(2..5), height: rand(0.1..0.5) },
    unit_of_measure: 'pieza',
    batch_tracking: [ 'Numismática', 'Billetes Históricos' ].include?(product.category.name),
    reorder_point: case product.category.name
                   when 'Numismática' then 2
                   when 'Monedas de Oro' then 5
                   when 'Lingotes' then 3
                   else 10
                   end,
    max_stock_level: case product.category.name
                     when 'Numismática' then 10
                     when 'Monedas de Oro' then 50
                     else 100
                     end,
    barcode: "BC#{product.id.to_s.rjust(8, '0')}"
  )
end
puts "✅ Updated products with WMS fields"

# Update existing stocks with WMS fields
Stock.where(location: nil).find_each do |stock|
  storage_location = Location.joins(zone: :warehouse)
                             .where(zones: { zone_type: 'storage' })
                             .active
                             .sample

  if storage_location
    begin
      stock.update!(
        location: storage_location,
        unit_cost: stock.product.price * 0.6, # 60% del precio de venta
        received_date: rand(30.days).seconds.ago
      )
    rescue => e
      puts "Error updating stock: #{e.message}"
      next
    end

    if stock.product.batch_tracking?
      stock.update!(
        batch_number: "BT#{Date.current.strftime('%Y%m')}#{rand(1000..9999)}",
        expiry_date: rand(365..1095).days.from_now # 1-3 años
      )
    end
  end
end
puts "✅ Updated stocks with WMS fields"

# Update existing orders with WMS fields
Order.where(warehouse: nil).find_each do |order|
  order.update!(
    warehouse: Warehouse.first,
    order_type: 'sales_order',
    fulfillment_status: case order.status
                        when 'delivered' then 'delivered'
                        when 'shipped' then 'shipped'
                        else 'pending'
                        end,
    priority: [ 'low', 'medium', 'high' ].sample,
    requested_ship_date: order.created_at + rand(1..5).days
  )
end
puts "✅ Updated orders with WMS fields"

# Create some sample tasks
if Task.count.zero?
  admin = Admin.first
  warehouse = Warehouse.first
  task_types = [ 'putaway', 'picking', 'replenishment', 'cycle_count' ]

  10.times do |i|
    product = Product.active.sample
    location = Location.active.sample

    begin
      task = Task.create!(
        admin: admin,
        warehouse: warehouse,
        task_type: task_types.sample,
        priority: [ 'low', 'medium', 'high', 'urgent' ].sample,
        status: [ 'pending', 'assigned' ].sample,
        product: product,
        location: location,
        quantity: rand(1..5),
        instructions: "Tarea de #{task_types.sample} para #{product.name} en #{location.coordinate_code}"
      )
    rescue => e
      puts "Error creating task: #{e.message}"
      next
    end
    puts "✅ Created task: #{task.display_name}"
  end
end

# Create some inventory transactions
if InventoryTransaction.count.zero?
  admin = Admin.first

  Stock.includes(:product, :location).limit(20).each do |stock|
    next unless stock.location

    # Create a receipt transaction
    InventoryTransaction.create!(
      warehouse: stock.location.warehouse,
      location: stock.location,
      product: stock.product,
      transaction_type: 'receipt',
      quantity: stock.amount,
      unit_cost: stock.unit_cost,
      admin: admin,
      reason: 'Initial stock receipt',
      batch_number: stock.batch_number,
      expiry_date: stock.expiry_date,
      created_at: stock.received_date || 1.week.ago
    )
  end
  puts "✅ Created initial inventory transactions"
end

puts ""
puts "🎯 WMS Seeds summary:"
puts "  🏭 Warehouses: #{Warehouse.count}"
puts "  📍 Zones: #{Zone.count}"
puts "  📦 Locations: #{Location.count}"
puts "  ✅ Tasks: #{Task.count}"
puts "  📊 Inventory Transactions: #{InventoryTransaction.count}"
puts ""
# Create pick lists (simple version without complex validations)
if PickList.count.zero?
  admin = Admin.first
  warehouse = Warehouse.first
  pending_orders = Order.where(fulfillment_status: 'pending').limit(3)

  pending_orders.each_with_index do |order, index|
    # Create basic pick list
    pick_list = PickList.new(
      order: order,
      warehouse: warehouse,
      admin: admin,
      status: 'pending',
      priority: [ 'low', 'medium', 'high' ].sample,
      pick_list_number: "PL#{Date.current.strftime('%Y%m%d')}#{(index + 1).to_s.rjust(4, '0')}",
      total_items: order.order_products.sum(:quantity),
      picked_items: 0
    )

    # Save without callbacks to avoid complex validations
    pick_list.save!(validate: false)

    puts "✅ Created basic pick list #{pick_list.pick_list_number} for order ##{order.id}"
  end
end

# Create receipts
if Receipt.count.zero?
  admin = Admin.first
  warehouses = Warehouse.all

  5.times do |i|
    receipt = Receipt.new(
      reference_number: "RCP-#{Date.current.strftime('%Y%m%d')}-#{(i+1).to_s.rjust(3, '0')}",
      warehouse: warehouses.sample,
      admin: admin,
      supplier_name: [ "Proveedor Alpha", "Distribuidora Beta", "Importadora Gamma" ].sample,
      status: 'pending',
      expected_date: rand(1..7).days.from_now,
      notes: "Recepción de mercancía #{i+1}"
    )

    receipt.save!(validate: false)

    puts "✅ Created receipt #{receipt.reference_number}"
  end
end

# Create simple cycle counts
if CycleCount.count.zero?
  admin = Admin.first
  warehouse = Warehouse.first
  locations = Location.active.limit(3)

  locations.each_with_index do |location, i|
    cycle_count = CycleCount.new(
      warehouse: warehouse,
      admin: admin,
      location: location,
      status: 'scheduled',
      count_type: 'spot_count',
      scheduled_date: Date.current + rand(1..30).days,
      notes: "Conteo programado para verificación de inventario"
    )

    cycle_count.save!(validate: false)
    puts "✅ Created cycle count for #{location.coordinate_code}"
  end
end

# Create simple shipments
if Shipment.count.zero?
  admin = Admin.first
  warehouse = Warehouse.first
  completed_orders = Order.limit(2)

  completed_orders.each_with_index do |order, i|
    shipment = Shipment.new(
      warehouse: warehouse,
      order: order,
      admin: admin,
      carrier: 'DHL',
      tracking_number: "TRK#{SecureRandom.hex(6).upcase}",
      status: 'preparing'
    )

    shipment.save!(validate: false)
    puts "✅ Created shipment #{shipment.tracking_number}"
  end
end

# Add more comprehensive inventory transactions
Stock.includes(:product, :location).limit(30).each do |stock|
  next unless stock.location

  # Create some movement transactions
  if rand < 0.3 # 30% chance
    movement_types = [ 'adjustment_in', 'adjustment_out', 'transfer_out', 'transfer_in' ]

    InventoryTransaction.create!(
      warehouse: stock.location.warehouse,
      location: stock.location,
      product: stock.product,
      transaction_type: movement_types.sample,
      quantity: rand(1..5),
      unit_cost: stock.unit_cost,
      admin: Admin.first,
      reason: 'Movimiento de inventario de ejemplo',
      batch_number: stock.batch_number,
      created_at: rand(7.days).seconds.ago
    )
  end
end

puts ""
puts "✅ Complete WMS seeding finished successfully! 🏭🚀"
puts ""
puts "📋 Note: Advanced WMS features can be managed through the admin interface:"
puts "   • Pick Lists - Generate from orders"
puts "   • Receipts - Create inbound shipments"
puts "   • Cycle Counts - Schedule inventory counts"
puts "   • Shipments - Track outbound deliveries"
