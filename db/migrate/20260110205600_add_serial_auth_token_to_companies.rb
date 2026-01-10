class AddSerialAuthTokenToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :serial_auth_token, :string
    add_index :companies, :serial_auth_token, unique: true
  end
end
