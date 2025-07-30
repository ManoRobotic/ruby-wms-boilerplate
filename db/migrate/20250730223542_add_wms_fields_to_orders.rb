class AddWmsFieldsToOrders < ActiveRecord::Migration[8.0]
  def change
    add_reference :orders, :warehouse, null: true, foreign_key: true, type: :uuid
    add_column :orders, :order_type, :string, default: 'sales_order'
    add_column :orders, :fulfillment_status, :string, default: 'pending'
    add_column :orders, :requested_ship_date, :date
    add_column :orders, :shipped_date, :date
    add_column :orders, :tracking_number, :string, limit: 100
    add_column :orders, :priority, :string, default: 'medium'
    add_column :orders, :notes, :text

    add_index :orders, :order_type
    add_index :orders, :fulfillment_status
    add_index :orders, :requested_ship_date
    add_index :orders, :priority
  end
end
