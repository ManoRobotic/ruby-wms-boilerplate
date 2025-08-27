class RenameEmpresaIdToCompanyIdInProductionOrders < ActiveRecord::Migration[8.0]
  def change
    rename_column :production_orders, :empresa_id, :company_id
  end
end
