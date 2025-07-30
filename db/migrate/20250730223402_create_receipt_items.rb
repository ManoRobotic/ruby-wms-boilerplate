class CreateReceiptItems < ActiveRecord::Migration[8.0]
  def change
    create_table :receipt_items, id: :uuid do |t|
      t.references :receipt, null: false, foreign_key: true, type: :uuid
      t.references :product, null: false, foreign_key: true, type: :uuid
      t.integer :expected_quantity
      t.integer :received_quantity
      t.decimal :unit_cost
      t.string :batch_number
      t.date :expiry_date
      t.references :location, null: false, foreign_key: true, type: :uuid
      t.string :status

      t.timestamps
    end
  end
end
