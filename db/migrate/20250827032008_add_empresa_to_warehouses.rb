class AddEmpresaToWarehouses < ActiveRecord::Migration[8.0]
  def change
    add_reference :warehouses, :empresa, null: true, foreign_key: true, type: :uuid
  end
end
