class AddRowTrackingToProductionOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :production_orders, :sheet_row_number, :integer
    add_column :production_orders, :last_sheet_update, :string
    add_column :production_orders, :needs_update_to_sheet, :boolean
  end
end
