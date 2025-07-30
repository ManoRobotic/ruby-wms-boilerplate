class AddWmsFieldsToStocks < ActiveRecord::Migration[8.0]
  def change
    add_reference :stocks, :location, null: true, foreign_key: true, type: :uuid
    add_column :stocks, :batch_number, :string, limit: 50
    add_column :stocks, :expiry_date, :date
    add_column :stocks, :reserved_quantity, :integer, default: 0
    add_column :stocks, :unit_cost, :decimal, precision: 10, scale: 2
    add_column :stocks, :received_date, :date

    add_index :stocks, :batch_number
    add_index :stocks, :expiry_date
    add_index :stocks, [ :product_id, :location_id, :batch_number ], name: 'index_stocks_on_product_location_batch'
  end
end
