class AddNewFieldsToProductionOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :production_orders, :peso, :decimal
    add_column :production_orders, :lote_referencia, :string
    add_column :production_orders, :no_opro, :string
    add_column :production_orders, :carga_copr, :decimal
    add_column :production_orders, :ano, :integer
    add_column :production_orders, :mes, :integer
    add_column :production_orders, :fecha_completa, :datetime
  end
end
