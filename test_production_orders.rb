#!/usr/bin/env ruby

# Test script to check production orders accessibility

require_relative 'config/environment'

# Find the Flexiempaques admin
admin = Admin.find_by(super_admin_role: 'flexiempaques')
puts "Admin found: #{admin.email}" if admin

# Check accessible production orders
if admin
  accessible_orders = admin.accessible_production_orders
  puts "Accessible production orders count: #{accessible_orders.count}"
  puts "SQL query: #{accessible_orders.to_sql}"
  
  # Check if there are any orders
  if accessible_orders.any?
    puts "First order: #{accessible_orders.first.order_number}"
  else
    puts "No accessible orders found"
  end
else
  puts "No Flexiempaques admin found"
end