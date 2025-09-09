class AddAutoSaveConsecutivoToCompanies < ActiveRecord::Migration[8.0]
  def change
    add_column :companies, :auto_save_consecutivo, :boolean
  end
end
