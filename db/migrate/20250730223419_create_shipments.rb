class CreateShipments < ActiveRecord::Migration[8.0]
  def change
    create_table :shipments, id: :uuid do |t|
      t.references :order, null: false, foreign_key: true, type: :uuid
      t.references :warehouse, null: false, foreign_key: true, type: :uuid
      t.references :admin, null: false, foreign_key: true, type: :uuid
      t.string :tracking_number
      t.string :carrier
      t.string :status
      t.date :shipped_date
      t.date :delivered_date
      t.decimal :total_weight
      t.decimal :shipping_cost
      t.jsonb :recipient_info

      t.timestamps
    end
  end
end
