class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Basic WMS table indexes that definitely exist

    # Warehouses
    add_index :warehouses, [ :code ], name: 'idx_warehouses_code' unless index_exists?(:warehouses, [ :code ])

    # Zones
    add_index :zones, [ :warehouse_id, :zone_type ], name: 'idx_zones_warehouse_type'
    add_index :zones, [ :warehouse_id ], name: 'idx_zones_warehouse'

    # Locations
    add_index :locations, [ :zone_id ], name: 'idx_locations_zone'
    add_index :locations, [ :aisle, :bay, :level ], name: 'idx_locations_position'
    add_index :locations, [ :current_volume, :capacity ], name: 'idx_locations_utilization'
    add_index :locations, [ :barcode ], where: 'barcode IS NOT NULL', name: 'idx_locations_barcode'

    # Pick lists
    add_index :pick_lists, [ :status, :priority, :created_at ], name: 'idx_pick_lists_status_priority_date'
    add_index :pick_lists, [ :warehouse_id, :status ], name: 'idx_pick_lists_warehouse_status'
    add_index :pick_lists, [ :admin_id, :status ], name: 'idx_pick_lists_admin_status'
    add_index :pick_lists, [ :order_id ], name: 'idx_pick_lists_order'
    add_index :pick_lists, [ :started_at ], where: 'started_at IS NOT NULL', name: 'idx_pick_lists_started_at'

    # Pick list items
    add_index :pick_list_items, [ :pick_list_id, :sequence ], name: 'idx_pick_list_items_sequence'
    add_index :pick_list_items, [ :location_id, :status ], name: 'idx_pick_list_items_location_status'
    add_index :pick_list_items, [ :product_id, :status ], name: 'idx_pick_list_items_product_status'
    add_index :pick_list_items, [ :status, :sequence ], name: 'idx_pick_list_items_status_sequence'

    # Tasks
    add_index :tasks, [ :status, :priority, :created_at ], name: 'idx_tasks_status_priority_date'
    add_index :tasks, [ :warehouse_id, :status ], name: 'idx_tasks_warehouse_status'
    add_index :tasks, [ :admin_id, :status ], name: 'idx_tasks_admin_status'
    add_index :tasks, [ :task_type, :status ], name: 'idx_tasks_type_status'
    add_index :tasks, [ :product_id ], where: 'product_id IS NOT NULL', name: 'idx_tasks_product'

    # Inventory transactions
    add_index :inventory_transactions, [ :warehouse_id, :created_at ], name: 'idx_inventory_transactions_warehouse_date'
    add_index :inventory_transactions, [ :product_id, :created_at ], name: 'idx_inventory_transactions_product_date'
    add_index :inventory_transactions, [ :location_id, :created_at ], name: 'idx_inventory_transactions_location_date'
    add_index :inventory_transactions, [ :transaction_type, :created_at ], name: 'idx_inventory_transactions_type_date'
    add_index :inventory_transactions, [ :batch_number ], where: 'batch_number IS NOT NULL', name: 'idx_inventory_transactions_batch'
    add_index :inventory_transactions, [ :admin_id, :created_at ], name: 'idx_inventory_transactions_admin_date'

    # Receipts
    add_index :receipts, [ :warehouse_id, :status ], name: 'idx_receipts_warehouse_status'
    add_index :receipts, [ :reference_number ], name: 'idx_receipts_reference_number'
    add_index :receipts, [ :received_date ], where: 'received_date IS NOT NULL', name: 'idx_receipts_received_date'

    # Cycle counts
    add_index :cycle_counts, [ :warehouse_id, :status ], name: 'idx_cycle_counts_warehouse_status'
    add_index :cycle_counts, [ :location_id, :status ], name: 'idx_cycle_counts_location_status'
    add_index :cycle_counts, [ :scheduled_date, :status ], name: 'idx_cycle_counts_scheduled_status'

    # Shipments
    add_index :shipments, [ :warehouse_id, :status ], name: 'idx_shipments_warehouse_status'
    add_index :shipments, [ :tracking_number ], name: 'idx_shipments_tracking_number'
    add_index :shipments, [ :shipped_date ], where: 'shipped_date IS NOT NULL', name: 'idx_shipments_shipped_date'

    # Composite indexes for complex queries
    add_index :pick_list_items, [ :pick_list_id, :location_id, :sequence ],
              name: 'idx_pick_list_items_route_optimization'

    add_index :tasks, [ :warehouse_id, :task_type, :status, :priority ],
              name: 'idx_tasks_warehouse_type_status_priority'
  end
end
