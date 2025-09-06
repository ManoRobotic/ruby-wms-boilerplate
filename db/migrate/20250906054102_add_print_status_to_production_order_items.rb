class AddPrintStatusToProductionOrderItems < ActiveRecord::Migration[8.0]
  def change
    add_column :production_order_items, :print_status, :integer, default: 0
  end
end
