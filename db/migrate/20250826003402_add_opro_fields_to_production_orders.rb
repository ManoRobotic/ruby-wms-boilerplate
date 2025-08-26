class AddOproFieldsToProductionOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :production_orders, :ren_orp, :string
    add_column :production_orders, :stat_opro, :string
  end
end
