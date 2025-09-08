require 'faker'

puts "Seeding essential data for Flexiempaques and Rzavala companies..."

# --- Empresas ---
empresas_data = [
  { name: "Flexiempaques", admin_email: "admin@flexiempaques.com", super_admin_role: "flexiempaques" },
  { name: "Rzavala", admin_email: "admin@rzavala.com", super_admin_role: "rzavala" }
]

empresas = []
admins = []

empresas_data.each_with_index do |empresa_data, i|
  # Create Empresa
  empresa = Company.find_or_initialize_by(name: empresa_data[:name])
  empresa.save!
  empresas << empresa
  puts "Created/Found Empresa: #{empresa.name}"

  # Create Warehouse
  warehouse = Warehouse.find_or_initialize_by(code: "WH#{i + 1}")
  warehouse.assign_attributes(
    name: "Warehouse for #{empresa.name}",
    address: Faker::Address.full_address,
    active: true,
    contact_info: { phone: Faker::PhoneNumber.phone_number, email: "warehouse#{i + 1}@#{empresa.name.downcase.gsub(' ', '')}.com" },
    company: empresa
  )
  warehouse.save!
  puts "Created/Found Warehouse: #{warehouse.name} for #{empresa.name}"

  # Create Admin
  admin = Admin.find_or_initialize_by(email: empresa_data[:admin_email])
  admin.assign_attributes(
    password: "password",
    password_confirmation: "password",
    name: "Admin - #{empresa.name}",
    address: Faker::Address.full_address,
    google_sheets_enabled: false,
    super_admin_role: empresa_data[:super_admin_role],
    company: empresa
  )
  admin.save!
  admins << admin
  puts "Created/Found Admin: #{admin.email} for #{empresa.name}"

  # Create Operators (Users)
  3.times do |j|
    user_email = "operator#{i + 1}_#{j + 1}@#{empresa.name.downcase.gsub(' ', '')}.com"
    user = User.find_or_initialize_by(email: user_email)
    user.assign_attributes(
      password: "password",
      password_confirmation: "password",
      name: "Operator #{i + 1}-#{j + 1}",
      role: ["picker", "operador", "supervisor"].sample,
      active: true,
      warehouse: warehouse,
      company: empresa,
      super_admin_role: empresa_data[:super_admin_role]
    )
    user.save!
    puts "Created/Found User: #{user.email} (Role: #{user.role}) for #{empresa.name}"
  end
end

# --- Categories ---
default_company = Company.first
if default_company
  ["Rollos", "Bolsas"].each do |category_name|
    category = Category.find_or_initialize_by(name: category_name, company: default_company)
    category.description = "Default category for #{category_name}"
    category.save!
    puts "Created/Found Category: #{category_name}"
  end
end