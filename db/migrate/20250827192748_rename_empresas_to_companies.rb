class RenameEmpresasToCompanies < ActiveRecord::Migration[8.0]
  def change
    rename_table :empresas, :companies
  end
end
