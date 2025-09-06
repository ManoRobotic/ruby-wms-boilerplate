class AddPrinterConfigurationToAdmins < ActiveRecord::Migration[8.0]
  def change
    add_column :admins, :printer_port, :string
    add_column :admins, :printer_baud_rate, :integer
    add_column :admins, :printer_parity, :string
    add_column :admins, :printer_stop_bits, :integer
    add_column :admins, :printer_data_bits, :integer
  end
end
