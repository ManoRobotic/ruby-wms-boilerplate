class AddSerialConfigurationToCompanies < ActiveRecord::Migration[8.0]
  def change
    add_column :companies, :google_sheets_enabled, :boolean
    add_column :companies, :sheet_id, :string
    add_column :companies, :google_credentials, :text
    add_column :companies, :serial_port, :string
    add_column :companies, :serial_baud_rate, :integer
    add_column :companies, :serial_parity, :string
    add_column :companies, :serial_stop_bits, :integer
    add_column :companies, :serial_data_bits, :integer
    add_column :companies, :printer_port, :string
    add_column :companies, :printer_baud_rate, :integer
    add_column :companies, :printer_parity, :string
    add_column :companies, :printer_stop_bits, :integer
    add_column :companies, :printer_data_bits, :integer
    add_column :companies, :last_sync_at, :datetime
    add_column :companies, :last_sync_checksum, :string
    add_column :companies, :total_orders_synced, :integer
  end
end
