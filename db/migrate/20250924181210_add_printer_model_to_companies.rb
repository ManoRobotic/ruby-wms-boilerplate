class AddPrinterModelToCompanies < ActiveRecord::Migration[8.0]
  def change
    add_column :companies, :printer_model, :string, default: 'zebra'
  end
end
