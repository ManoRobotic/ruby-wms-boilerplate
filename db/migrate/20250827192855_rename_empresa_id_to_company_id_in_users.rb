class RenameEmpresaIdToCompanyIdInUsers < ActiveRecord::Migration[8.0]
  def change
    rename_column :users, :empresa_id, :company_id
  end
end
