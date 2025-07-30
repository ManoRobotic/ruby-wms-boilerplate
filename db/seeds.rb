# Clear existing data
puts "🗑️  Clearing existing data..."
Order.destroy_all
Product.destroy_all
Category.destroy_all
Admin.destroy_all

puts "👤 Creating admin user..."
admin = Admin.create!(
  email: "admin@wmsapp.com",
  password: "password123",
  password_confirmation: "password123",
  name: "Admin Principal",
  address: "Ciudad de México, México"
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