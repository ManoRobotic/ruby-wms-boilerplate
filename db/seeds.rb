require 'faker'

puts "Cleaning database..."


# Destroy dependent records first to avoid foreign key constraints
# Only destroy essential records that will be re-created
User.destroy_all
Admin.destroy_all
Warehouse.destroy_all
Empresa.destroy_all
Category.destroy_all

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
  empresa = Company.find_or_create_by!(name: empresa_data[:name]) do |e|
    e.created_at = Time.now
    e.updated_at = Time.now
  end
  empresas << empresa
  puts "Created/Found Empresa: #{empresa.name}"

  # Create Warehouse
  warehouse = Warehouse.find_or_create_by!(code: "WH#{i + 1}") do |wh|
    wh.name = "Warehouse for #{empresa.name}"
    wh.address = Faker::Address.full_address
    wh.active = true
    wh.contact_info = { phone: Faker::PhoneNumber.phone_number, email: "warehouse#{i + 1}@#{empresa.name.downcase.gsub(' ', '')}.com" }
    wh.empresa = empresa
    wh.created_at = Time.now
    wh.updated_at = Time.now
  end
  puts "Created/Found Warehouse: #{warehouse.name} for #{empresa.name}"

  # Create Admin
  admin = Admin.find_or_create_by!(email: empresa_data[:admin_email]) do |a|
    a.password = "password"
    a.password_confirmation = "password"
    a.name = "Admin - #{empresa.name}"
    a.address = Faker::Address.full_address
    a.google_sheets_enabled = false
    a.super_admin_role = empresa_data[:super_admin_role]
    a.empresa = empresa
    a.created_at = Time.now
    a.updated_at = Time.now
  end
  admins << admin
  puts "Created/Found Admin: #{admin.email} for #{empresa.name}"

  # Create Operators (Users)
  3.times do |j|
    user_email = "operator#{i + 1}_#{j + 1}@#{empresa.name.downcase.gsub(' ', '')}.com"
    user = User.find_or_create_by!(email: user_email) do |u|
      u.password = "password"
      u.password_confirmation = "password"
      u.name = "Operator #{i + 1}-#{j + 1}"
      u.role = ["picker", "operador", "supervisor"].sample
      u.active = true
      u.warehouse = warehouse
      u.super_admin_role = empresa_data[:super_admin_role]
      u.created_at = Time.now
      u.updated_at = Time.now
    end
    puts "Created/Found User: #{user.email} (Role: #{user.role}) for #{empresa.name}"
  end
end

# --- Categories ---
["Rollos", "Bolsas"].each do |category_name|
  Category.find_or_create_by!(name: category_name) do |c|
    c.description = "Default category for #{category_name}"
    c.created_at = Time.now
    c.updated_at = Time.now
  end
  puts "Created/Found Category: #{category_name}"
end