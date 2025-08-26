class AddClientFieldsToProductionOrderItems < ActiveRecord::Migration[8.0]
  def change
    add_column :production_order_items, :cliente, :string
    add_column :production_order_items, :numero_de_orden, :string
    add_column :production_order_items, :nombre_cliente_numero_pedido, :string
  end
end
