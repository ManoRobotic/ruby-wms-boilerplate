class AddSerialDeviceIdToCompanies < ActiveRecord::Migration[8.0]
  def change
    add_column :companies, :serial_device_id, :string
  end
end