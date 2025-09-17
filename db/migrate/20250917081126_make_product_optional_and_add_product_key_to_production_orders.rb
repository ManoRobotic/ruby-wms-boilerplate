class MakeProductOptionalAndAddProductKeyToProductionOrders < ActiveRecord::Migration[8.0]
  def change
    # Make product_id optional
    change_column_null :production_orders, :product_id, true
    
    # Add product_key field
    add_column :production_orders, :product_key, :string
  end
end
