class AddWmsFieldsToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :sku, :string, limit: 50
    add_column :products, :weight, :decimal, precision: 8, scale: 3
    add_column :products, :dimensions, :jsonb, default: {}
    add_column :products, :reorder_point, :integer, default: 10
    add_column :products, :max_stock_level, :integer, default: 1000
    add_column :products, :batch_tracking, :boolean, default: false
    add_column :products, :unit_of_measure, :string, default: 'unit'
    add_column :products, :barcode, :string, limit: 50

    add_index :products, :sku, unique: true, where: "sku IS NOT NULL"
    add_index :products, :barcode, unique: true, where: "barcode IS NOT NULL"
    add_index :products, :batch_tracking
  end
end
