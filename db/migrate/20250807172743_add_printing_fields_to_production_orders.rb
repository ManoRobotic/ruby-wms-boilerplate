class AddPrintingFieldsToProductionOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :production_orders, :bag_size, :string
    add_column :production_orders, :bag_measurement, :string
    add_column :production_orders, :pieces_count, :integer
    add_column :production_orders, :package_count, :integer
    add_column :production_orders, :package_measurement, :string
  end
end
