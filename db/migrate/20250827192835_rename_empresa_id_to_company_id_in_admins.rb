class RenameEmpresaIdToCompanyIdInAdmins < ActiveRecord::Migration[8.0]
  def change
    rename_column :admins, :empresa_id, :company_id
  end
end
