# Seeds file for WMS Ruby Boilerplate - Comprehensive Setup
# This file should be idempotent - can be run multiple times safely

puts "🌱 Iniciando seeds..."

# =============================================================================
# BASIC DATA SETUP
# =============================================================================

puts "\n📦 Creando datos básicos..."

# Categories
category_general = Category.find_or_create_by!(name: "General") do |c|
  c.description = "Productos generales"
end

category_plásticos = Category.find_or_create_by!(name: "Plásticos") do |c|
  c.description = "Productos plásticos y empaques"
end

puts "✅ Categorías creadas: #{Category.count}"

# Warehouses
warehouse_principal = Warehouse.find_or_create_by!(name: "Almacén Principal", code: "MAIN") do |w|
  w.address = "Dirección Principal"
  w.active = true
end

warehouse_rzavala = Warehouse.find_or_create_by!(name: "Almacén R.Zavala", code: "RZ01") do |w|
  w.address = "Almacén R.Zavala - Ubicación A"
  w.active = true
end

warehouse_flexiempaques = Warehouse.find_or_create_by!(name: "Almacén FlexiEmpaques", code: "FE01") do |w|
  w.address = "Almacén FlexiEmpaques - Planta Principal"
  w.active = true
end

puts "✅ Almacenes creados: #{Warehouse.count}"

# Products
products_data = [
  { name: "BOPPTRANS 35 / 420", description: "Película transparente 35 micras, ancho 420mm", price: 150.0 },
  { name: "BOPPTRANS 20 / 220", description: "Película transparente 20 micras, ancho 220mm", price: 120.0 },
  { name: "BOPPTRANS 50 / 350", description: "Película transparente 50 micras, ancho 350mm", price: 180.0 },
  { name: "BOPPTRANS 25 / 300", description: "Película transparente 25 micras, ancho 300mm", price: 135.0 },
  { name: "BOPPMET 40 / 450", description: "Película metalizada 40 micras, ancho 450mm", price: 200.0 }
]

products_data.each do |product_data|
  Product.find_or_create_by!(name: product_data[:name]) do |p|
    p.description = product_data[:description]
    p.price = product_data[:price]
    p.category = category_plásticos
    p.active = true
  end
end

puts "✅ Productos creados: #{Product.count}"

# =============================================================================
# SUPER ADMIN USERS
# =============================================================================

puts "\n👑 Creando Super Administradores..."

# Super Admin - rzavala
rzavala_admin = Admin.find_or_initialize_by(email: 'rzavala@company.com')
rzavala_admin.assign_attributes(
  name: 'R. Zavala',
  super_admin_role: 'rzavala',
  password: 'password123',
  password_confirmation: 'password123',
  google_sheets_enabled: false
)

if rzavala_admin.save
  puts "✅ Super Admin rzavala creado: #{rzavala_admin.email}"
else
  puts "❌ Error creando rzavala: #{rzavala_admin.errors.full_messages.join(', ')}"
end

# Super Admin - flexiempaques
flexiempaques_admin = Admin.find_or_initialize_by(email: 'admin@flexiempaques.com')
flexiempaques_admin.assign_attributes(
  name: 'FlexiEmpaques Admin',
  super_admin_role: 'flexiempaques',
  password: 'password123',
  password_confirmation: 'password123',
  google_sheets_enabled: false
)

if flexiempaques_admin.save
  puts "✅ Super Admin flexiempaques creado: #{flexiempaques_admin.email}"
else
  puts "❌ Error creando flexiempaques: #{flexiempaques_admin.errors.full_messages.join(', ')}"
end

# =============================================================================
# OPERATORS FOR EACH SUPER ADMIN
# =============================================================================

puts "\n👷 Creando operadores..."

# Operators for rzavala
rzavala_operators = [
  { email: 'operador1.rzavala@company.com', name: 'Carlos Martínez' },
  { email: 'operador2.rzavala@company.com', name: 'María García' }
]

rzavala_operators.each do |op_data|
  operator = Admin.find_or_initialize_by(email: op_data[:email])
  operator.assign_attributes(
    name: op_data[:name],
    super_admin_role: 'rzavala',
    password: 'password123',
    password_confirmation: 'password123',
    google_sheets_enabled: false
  )
  
  if operator.save
    puts "✅ Operador rzavala creado: #{operator.email}"
  else
    puts "❌ Error creando operador rzavala: #{operator.errors.full_messages.join(', ')}"
  end
end

# Operators for flexiempaques
flexiempaques_operators = [
  { email: 'operador1.flexi@flexiempaques.com', name: 'Ana López' },
  { email: 'operador2.flexi@flexiempaques.com', name: 'Roberto Silva' }
]

flexiempaques_operators.each do |op_data|
  operator = Admin.find_or_initialize_by(email: op_data[:email])
  operator.assign_attributes(
    name: op_data[:name],
    super_admin_role: 'flexiempaques',
    password: 'password123',
    password_confirmation: 'password123',
    google_sheets_enabled: false
  )
  
  if operator.save
    puts "✅ Operador flexiempaques creado: #{operator.email}"
  else
    puts "❌ Error creando operador flexiempaques: #{operator.errors.full_messages.join(', ')}"
  end
end

# =============================================================================
# SAMPLE PRODUCTION ORDERS WITH NOTES
# =============================================================================

puts "\n📋 Creando órdenes de producción de ejemplo..."

# Sample Production Orders for rzavala
rzavala_orders = [
  {
    no_opro: "RZ-001",
    product_name: "BOPPTRANS 35 / 420",
    warehouse: warehouse_rzavala,
    notes: "Orden urgente para cliente premium. Revisar calidad antes del empaque.",
    quantity: 500,
    status: "in_progress"
  },
  {
    no_opro: "RZ-002", 
    product_name: "BOPPTRANS 20 / 220",
    warehouse: warehouse_rzavala,
    notes: "Control especial de temperatura durante producción. Mantener entre 18-22°C.",
    quantity: 750,
    status: "pending"
  },
  {
    no_opro: "RZ-003",
    product_name: "BOPPMET 40 / 450",
    warehouse: warehouse_rzavala,
    notes: "Material metalizado sensible a humedad. Almacenar en área seca.",
    quantity: 300,
    status: "completed"
  }
]

rzavala_orders.each do |order_data|
  product = Product.find_by(name: order_data[:product_name])
  next unless product

  order = ProductionOrder.find_or_initialize_by(
    no_opro: order_data[:no_opro],
    admin_id: rzavala_admin.id
  )
  
  order.assign_attributes(
    warehouse: order_data[:warehouse],
    product: product,
    quantity_requested: order_data[:quantity],
    notes: order_data[:notes],
    status: order_data[:status],
    priority: "medium",
    lote_referencia: "FE-CR-#{Date.current.strftime('%d%m%y')}"
  )

  if order.save
    puts "✅ Orden rzavala creada: #{order.no_opro} - #{order.notes[0..50]}..."
  else
    puts "❌ Error creando orden rzavala: #{order.errors.full_messages.join(', ')}"
  end
end

# Sample Production Orders for flexiempaques
flexiempaques_orders = [
  {
    no_opro: "FE-001",
    product_name: "BOPPTRANS 25 / 300",
    warehouse: warehouse_flexiempaques,
    notes: "Cliente solicita certificación FDA. Incluir documentación en envío.",
    quantity: 1000,
    status: "in_progress"
  },
  {
    no_opro: "FE-002",
    product_name: "BOPPTRANS 50 / 350", 
    warehouse: warehouse_flexiempaques,
    notes: "Orden de exportación. Verificar embalaje para transporte marítimo.",
    quantity: 800,
    status: "scheduled"
  },
  {
    no_opro: "FE-003",
    product_name: "BOPPTRANS 35 / 420",
    warehouse: warehouse_flexiempaques,
    notes: "Producción en dos lotes. Primer lote: 600 unidades. Segundo lote: 400 unidades.",
    quantity: 1000,
    status: "pending"
  },
  {
    no_opro: "914",
    product_name: "BOPPTRANS 20 / 220",
    warehouse: warehouse_flexiempaques,
    notes: "Orden con especificaciones especiales del cliente ABC. Verificar grosor exacto.",
    quantity: 1,
    status: "pending"
  }
]

flexiempaques_orders.each do |order_data|
  product = Product.find_by(name: order_data[:product_name])
  next unless product

  order = ProductionOrder.find_or_initialize_by(
    no_opro: order_data[:no_opro],
    admin_id: flexiempaques_admin.id
  )
  
  order.assign_attributes(
    warehouse: order_data[:warehouse],
    product: product,
    quantity_requested: order_data[:quantity],
    notes: order_data[:notes],
    status: order_data[:status],
    priority: "medium",
    lote_referencia: "FE-CR-#{Date.current.strftime('%d%m%y')}"
  )

  if order.save
    puts "✅ Orden flexiempaques creada: #{order.no_opro} - #{order.notes[0..50]}..."
  else
    puts "❌ Error creando orden flexiempaques: #{order.errors.full_messages.join(', ')}"
  end
end

# =============================================================================
# SAMPLE PACKING RECORDS
# =============================================================================

puts "\n📦 Creando registros de empaque..."

ProductionOrder.includes(:product).each do |order|
  next if order.packing_records.exists?
  
  # Extract micras and ancho from product name
  if match = order.product.name.match(/(\d+)\s*\/\s*(\d+)/)
    micras = match[1].to_i
    ancho_mm = match[2].to_i
    
    packing_record = order.packing_records.create!(
      lote: order.lote_referencia,
      cve_prod: order.product.name,
      peso_bruto: rand(10.0..50.0).round(2),
      peso_neto: rand(8.0..45.0).round(2), 
      metros_lineales: rand(100.0..1000.0).round(2),
      consecutivo: 1,
      micras: micras,
      ancho_mm: ancho_mm,
      nombre: order.product.name,
      cliente: ["Cliente A", "Cliente B", "Cliente Premium", "Exportación"].sample
    )
    
    puts "✅ Registro de empaque creado para orden #{order.no_opro}"
  end
end

# =============================================================================
# USERS (WAREHOUSE STAFF)
# =============================================================================

puts "\n👥 Creando usuarios de almacén..."

users_data = [
  { email: 'almacenista1.rz@company.com', name: 'Pedro Hernández', warehouse: warehouse_rzavala, role: 'operator' },
  { email: 'almacenista2.rz@company.com', name: 'Lucía Ramírez', warehouse: warehouse_rzavala, role: 'operator' },
  { email: 'almacenista1.fe@flexiempaques.com', name: 'José Torres', warehouse: warehouse_flexiempaques, role: 'operator' },
  { email: 'almacenista2.fe@flexiempaques.com', name: 'Carmen Flores', warehouse: warehouse_flexiempaques, role: 'operator' }
]

users_data.each do |user_data|
  user = User.find_or_initialize_by(email: user_data[:email])
  user.assign_attributes(
    name: user_data[:name],
    password: 'password123',
    password_confirmation: 'password123',
    role: user_data[:role],
    warehouse: user_data[:warehouse],
    active: true
  )
  
  if user.save
    puts "✅ Usuario creado: #{user.email} (#{user.warehouse.name})"
  else
    puts "❌ Error creando usuario: #{user.errors.full_messages.join(', ')}"
  end
end

# =============================================================================
# BASIC WMS SETUP
# =============================================================================

puts "\n🏭 Configurando estructuras básicas de WMS..."

# Create zones for each warehouse
Warehouse.find_each do |warehouse|
  next if warehouse.zones.exists?
  
  zone_types = ['receiving', 'storage', 'picking', 'packing', 'shipping']
  
  zone_types.each_with_index do |zone_type, index|
    zone = warehouse.zones.create!(
      name: "Zona #{zone_type.titleize} #{index + 1}",
      code: "#{zone_type.upcase[0..2]}#{index + 1}",
      zone_type: zone_type,
      description: "Área de operaciones de #{zone_type.titleize}"
    )
  end
end

# Create some basic locations in storage zones
Zone.where(zone_type: 'storage').find_each do |zone|
  next if zone.locations.exists?
  
  (1..2).each do |aisle|
    (1..3).each do |bay|
      (1..2).each do |level|
        zone.locations.create!(
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
end

# Create basic stock entries
products_data.each do |product_data|
  product = Product.find_by(name: product_data[:name])
  next unless product
  next if Stock.exists?(product: product)
  
  storage_location = Location.joins(zone: :warehouse)
                            .where(zones: { zone_type: 'storage' })
                            .first
  
  if storage_location
    Stock.create!(
      product: product,
      amount: rand(50..200),
      location: storage_location,
      unit_cost: product.price * 0.6,
      received_date: rand(30.days).seconds.ago
    )
  end
end

puts "✅ Configuración básica de WMS completada"

# =============================================================================
# SUMMARY
# =============================================================================

puts "\n" + "="*60
puts "🎉 SEEDS COMPLETADOS"
puts "="*60
puts "📊 RESUMEN:"
puts "   • Categorías: #{Category.count}"
puts "   • Almacenes: #{Warehouse.count}" 
puts "   • Productos: #{Product.count}"
puts "   • Super Admins: #{Admin.super_admins.count}"
puts "   • Admins totales: #{Admin.count}"
puts "   • Usuarios: #{User.count}"
puts "   • Órdenes de producción: #{ProductionOrder.count}"
puts "   • Registros de empaque: #{PackingRecord.count}"
puts "   • Zonas: #{Zone.count}"
puts "   • Ubicaciones: #{Location.count}"
puts "   • Stock: #{Stock.count}"
puts ""
puts "👑 SUPER ADMINISTRADORES:"
puts "   • rzavala@company.com (password: password123)"
puts "   • admin@flexiempaques.com (password: password123)"
puts ""
puts "👷 OPERADORES POR SUPER ADMIN:"
puts "   rzavala:"
puts "     - operador1.rzavala@company.com (Carlos Martínez)"
puts "     - operador2.rzavala@company.com (María García)"
puts "   flexiempaques:"
puts "     - operador1.flexi@flexiempaques.com (Ana López)"  
puts "     - operador2.flexi@flexiempaques.com (Roberto Silva)"
puts ""
puts "👥 USUARIOS DE ALMACÉN:"
users_data.each { |u| puts "     - #{u[:email]} (#{u[:name]})" }
puts ""
puts "📋 ÓRDENES DE PRODUCCIÓN CON NOTAS:"
ProductionOrder.where.not(notes: nil).each do |order|
  puts "   • #{order.no_opro}: #{order.notes[0..60]}#{'...' if order.notes.length > 60}"
end
puts ""
puts "✨ Todas las contraseñas son: password123"
puts "="*60