class ChangeAdminIdToUuidInProductionOrders < ActiveRecord::Migration[8.0]
  def up
    # Change admin_id column type from string to uuid
    # PostgreSQL can cast string UUIDs to uuid type directly
    change_column :production_orders, :admin_id, 'uuid USING admin_id::uuid'
  end

  def down
    # Revert back to string if needed
    change_column :production_orders, :admin_id, :string
  end
end
