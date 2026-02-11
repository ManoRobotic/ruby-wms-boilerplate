class AddClaveProductoToLocalProductionOrderItems < ActiveRecord::Migration[8.0]
  def change
    add_column :production_order_items, :clave_producto_local, :string
  end
end