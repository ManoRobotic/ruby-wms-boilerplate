class AddDefaultClaveProductoToProductionOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :production_orders, :default_clave_producto_consecutivo, :string
  end
end