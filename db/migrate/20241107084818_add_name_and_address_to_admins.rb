class AddNameAndAddressToAdmins < ActiveRecord::Migration[7.2]
  def change
    add_column :admins, :name, :string
    add_column :admins, :address, :string
  end
end
