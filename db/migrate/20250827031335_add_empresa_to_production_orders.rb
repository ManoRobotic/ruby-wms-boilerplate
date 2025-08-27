class AddEmpresaToProductionOrders < ActiveRecord::Migration[8.0]
  def change
    add_reference :production_orders, :empresa, null: true, foreign_key: true, type: :uuid
  end
end
