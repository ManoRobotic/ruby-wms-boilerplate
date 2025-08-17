# Demo data for Excel Processor functionality
puts "Setting up Excel Processor demo data..."

# Create warehouse if not exists
warehouse = Warehouse.find_or_create_by(code: "MAIN") do |w|
  w.name = "Almacén Principal"
  w.address = "Dirección del almacén principal"
  w.active = true
end

# Create categories for BOPP products
bopp_category = Category.find_or_create_by(name: "Productos BOPP") do |c|
  c.description = "Productos de polipropileno biorientado (BOPP)"
end

# Sample BOPP products based on CVE_PROP format
products_data = [
  { name: "BOPPTRANS 35 / 420", desc: "BOPP Transparente 35 micras, 420mm ancho" },
  { name: "BOPPTRANS 20 / 530", desc: "BOPP Transparente 20 micras, 530mm ancho" },
  { name: "BOPPTRANS 35 / 380", desc: "BOPP Transparente 35 micras, 380mm ancho" },
  { name: "BOPPTRANS 35 / 700", desc: "BOPP Transparente 35 micras, 700mm ancho" },
  { name: "BOPPTRANS 25 / 430", desc: "BOPP Transparente 25 micras, 430mm ancho" }
]

products = []
products_data.each do |product_data|
  product = Product.find_or_create_by(name: product_data[:name]) do |p|
    p.description = product_data[:desc]
    p.category = bopp_category
    p.sku = product_data[:name].gsub(/[^A-Z0-9]/, '')[0..20]
    p.active = true
    p.price = rand(100..500)
  end
  products << product
end

# Create sample production orders
puts "Creating sample production orders..."

sample_orders = [
  {
    product: products[0], # BOPPTRANS 35 / 420
    quantity: 300,
    status: "completed",
    no_opro: "DEMO001",
    lote_referencia: "FE-C-040423",
    carga_copr: 302.8,
    notes: "Orden de demostración para BOPPTRANS 35/420"
  },
  {
    product: products[1], # BOPPTRANS 20 / 530
    quantity: 320,
    status: "in_progress",
    no_opro: "DEMO002",
    lote_referencia: "FE-C-100423",
    carga_copr: 438.7,
    notes: "Orden en progreso para BOPPTRANS 20/530"
  },
  {
    product: products[2], # BOPPTRANS 35 / 380
    quantity: 640,
    status: "pending",
    no_opro: "DEMO003",
    lote_referencia: "FE-R-13042023",
    carga_copr: 622.5,
    notes: "Orden pendiente para BOPPTRANS 35/380"
  }
]

production_orders = []
sample_orders.each do |order_data|
  production_order = ProductionOrder.find_or_create_by(no_opro: order_data[:no_opro]) do |po|
    po.warehouse = warehouse
    po.product = order_data[:product]
    po.quantity_requested = order_data[:quantity]
    po.status = order_data[:status]
    po.priority = "medium"
    po.notes = order_data[:notes]
    po.lote_referencia = order_data[:lote_referencia]
    po.carga_copr = order_data[:carga_copr]
    po.ano = 2023
    po.mes = 4
    po.fecha_completa = Date.parse("2023-04-#{rand(1..30)}")
    
    if order_data[:status] == "completed"
      po.quantity_produced = order_data[:quantity]
      po.actual_completion = 1.week.ago
    elsif order_data[:status] == "in_progress"
      po.quantity_produced = (order_data[:quantity] * 0.6).to_i
      po.start_date = 3.days.ago
    end
  end
  production_orders << production_order
end

# Create sample packing records
puts "Creating sample packing records..."

# For the completed order, create multiple packing records
completed_order = production_orders.first
if completed_order&.completed?
  (1..5).each do |consecutivo|
    PackingRecord.find_or_create_by(
      production_order: completed_order,
      consecutivo: consecutivo,
      lote: "#{completed_order.lote_referencia}-#{consecutivo.to_s.rjust(2, '0')}"
    ) do |pr|
      pr.lote_padre = completed_order.lote_referencia
      pr.cve_prod = completed_order.product.name
      pr.peso_bruto = rand(40.0..60.0).round(2)
      pr.peso_neto = pr.peso_bruto - rand(0.5..2.0).round(2)
      pr.metros_lineales = rand(500..1000).round(2)
      pr.nombre = "Cliente Demo #{consecutivo}"
      pr.descripcion = "Empaque #{consecutivo} para #{completed_order.product.name}"
      pr.num_orden = completed_order.order_number
    end
  end
end

# For the in-progress order, create some packing records
in_progress_order = production_orders[1]
if in_progress_order&.in_progress?
  (1..3).each do |consecutivo|
    PackingRecord.find_or_create_by(
      production_order: in_progress_order,
      consecutivo: consecutivo,
      lote: "#{in_progress_order.lote_referencia}-#{consecutivo.to_s.rjust(2, '0')}"
    ) do |pr|
      pr.lote_padre = in_progress_order.lote_referencia
      pr.cve_prod = in_progress_order.product.name
      pr.peso_bruto = rand(35.0..50.0).round(2)
      pr.peso_neto = pr.peso_bruto - rand(0.3..1.5).round(2)
      pr.metros_lineales = rand(600..900).round(2)
      pr.nombre = "Cliente en Proceso #{consecutivo}"
      pr.descripcion = "Empaque en proceso #{consecutivo}"
      pr.num_orden = in_progress_order.order_number
    end
  end
end

puts "✅ Excel Processor demo data created successfully!"
puts "📊 Created:"
puts "   - #{products.count} BOPP products"
puts "   - #{production_orders.count} production orders"
puts "   - #{PackingRecord.count} packing records"
puts ""
puts "🌐 You can now visit: /admin/excel_processor"
puts "📁 Place your 'merged.xlsx' and 'FE BASE DE DATOS.xlsx' files in the Rails root directory"
puts "🔄 Then use the Excel processor to import real data!"