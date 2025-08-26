class AddSuperAdminRoleToAdmins < ActiveRecord::Migration[8.0]
  def change
    add_column :admins, :super_admin_role, :string
    add_index :admins, :super_admin_role
  end
end
