class CreateProductionOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :production_orders, id: :uuid do |t|
      t.string :order_number, null: false
      t.string :status, null: false, default: 'pending'
      t.string :priority, null: false, default: 'medium'
      t.references :warehouse, null: false, foreign_key: true, type: :uuid
      t.references :product, null: false, foreign_key: true, type: :uuid
      t.string :admin_id # Polymorphic for both Admin and User
      t.integer :quantity_requested, null: false
      t.integer :quantity_produced, default: 0
      t.datetime :start_date
      t.datetime :end_date
      t.datetime :estimated_completion
      t.datetime :actual_completion
      t.text :notes

      t.timestamps
    end

    add_index :production_orders, :order_number, unique: true
    add_index :production_orders, :status
    add_index :production_orders, :priority
    add_index :production_orders, :admin_id
    add_index :production_orders, :created_at
  end
end
