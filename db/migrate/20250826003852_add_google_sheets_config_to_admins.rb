class AddGoogleSheetsConfigToAdmins < ActiveRecord::Migration[8.0]
  def change
    add_column :admins, :google_sheets_enabled, :boolean
    add_column :admins, :google_credentials, :text
    add_column :admins, :sheet_id, :string
    add_column :admins, :worksheet_gid, :string
  end
end
