class AddSuperAdminRoleToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :super_admin_role, :string
  end
end
