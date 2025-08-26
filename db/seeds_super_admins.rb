# Super Admin Seeds
# Create the two super admin users: rzavala and flexiempaques

puts "Creating Super Admin users..."

# Create rzavala super admin
rzavala = Admin.find_or_initialize_by(email: 'rzavala@company.com')
rzavala.assign_attributes(
  name: 'R. Zavala',
  super_admin_role: 'rzavala',
  password: 'password123',
  password_confirmation: 'password123'
)

if rzavala.save
  puts "✅ Created/Updated rzavala super admin: #{rzavala.email}"
else
  puts "❌ Failed to create rzavala super admin: #{rzavala.errors.full_messages.join(', ')}"
end

# Create flexiempaques super admin
flexiempaques = Admin.find_or_initialize_by(email: 'admin@flexiempaques.com')
flexiempaques.assign_attributes(
  name: 'FlexiEmpaques Admin',
  super_admin_role: 'flexiempaques',
  password: 'password123',
  password_confirmation: 'password123'
)

if flexiempaques.save
  puts "✅ Created/Updated flexiempaques super admin: #{flexiempaques.email}"
else
  puts "❌ Failed to create flexiempaques super admin: #{flexiempaques.errors.full_messages.join(', ')}"
end

puts "\nSuper Admin users created successfully!"
puts "- rzavala: rzavala@company.com (password: password123)"
puts "- flexiempaques: admin@flexiempaques.com (password: password123)"