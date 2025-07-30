class CreateInventoryTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :inventory_transactions, id: :uuid do |t|
      t.references :warehouse, null: false, foreign_key: true, type: :uuid
      t.references :location, null: true, foreign_key: true, type: :uuid
      t.references :product, null: false, foreign_key: true, type: :uuid
      t.string :transaction_type, null: false
      t.integer :quantity, null: false
      t.decimal :unit_cost, precision: 10, scale: 2
      t.string :reference_type
      t.uuid :reference_id
      t.references :admin, null: false, foreign_key: true, type: :uuid
      t.text :reason
      t.string :batch_number, limit: 50
      t.date :expiry_date
      t.string :size

      t.timestamps
    end

    add_index :inventory_transactions, :transaction_type
    add_index :inventory_transactions, [ :reference_type, :reference_id ]
    add_index :inventory_transactions, :batch_number
    add_index :inventory_transactions, :created_at
  end
end
