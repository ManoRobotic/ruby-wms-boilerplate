#!/usr/bin/env ruby

# Test script to simulate what the controller is doing

require_relative 'config/environment'

# Find the Flexiempaques admin
admin = Admin.find_by(super_admin_role: 'flexiempaques')
puts "Admin found: #{admin.email}" if admin
puts "Admin super_admin?: #{admin.super_admin?}"
puts "Admin super_admin_role: #{admin.super_admin_role}"

# Simulate what the controller does
if admin
  puts "\n--- Simulating controller logic ---"
  
  # This is what the controller does
  production_orders = ProductionOrder.includes(:warehouse, :product, :packing_records)
  puts "Initial production orders count: #{production_orders.count}"
  
  # Check if admin is super admin
  if admin.super_admin?
    puts "Admin is super admin"
  else
    puts "Admin is regular admin"
    # Regular admin sees orders associated with their admin_id
    accessible_orders = admin.accessible_production_orders
    puts "Accessible production orders SQL: #{accessible_orders.to_sql}"
    puts "Accessible production orders count: #{accessible_orders.count}"
    
    # Apply the same filtering as in the controller
    production_orders = accessible_orders
  end
  
  # Apply pagination like in the controller
  paginated_orders = production_orders.recent.page(1).per(10)
  puts "Paginated orders count: #{paginated_orders.total_count}"
  puts "Paginated orders empty?: #{paginated_orders.empty?}"
  
  if paginated_orders.any?
    puts "First order: #{paginated_orders.first.order_number}"
  else
    puts "No orders found after pagination"
  end
else
  puts "No Flexiempaques admin found"
end