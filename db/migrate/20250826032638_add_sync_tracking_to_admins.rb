class AddSyncTrackingToAdmins < ActiveRecord::Migration[8.0]
  def change
    add_column :admins, :last_sync_at, :datetime
    add_column :admins, :last_sync_checksum, :string
    add_column :admins, :total_orders_synced, :integer
  end
end
