class AddSerialServiceUrlToCompanies < ActiveRecord::Migration[8.0]
  def change
    add_column :companies, :serial_service_url, :string
  end
end
