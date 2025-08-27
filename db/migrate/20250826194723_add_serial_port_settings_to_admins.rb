class AddSerialPortSettingsToAdmins < ActiveRecord::Migration[8.0]
  def change
    add_column :admins, :serial_port, :string
    add_column :admins, :serial_baud_rate, :integer
    add_column :admins, :serial_parity, :string
    add_column :admins, :serial_stop_bits, :integer
    add_column :admins, :serial_data_bits, :integer
  end
end
