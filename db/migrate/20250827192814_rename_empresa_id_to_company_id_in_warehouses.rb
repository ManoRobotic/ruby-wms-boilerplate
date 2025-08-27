class RenameEmpresaIdToCompanyIdInWarehouses < ActiveRecord::Migration[8.0]
  def change
    rename_column :warehouses, :empresa_id, :company_id
  end
end
