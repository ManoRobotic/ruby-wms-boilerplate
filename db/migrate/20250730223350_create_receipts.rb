class CreateReceipts < ActiveRecord::Migration[8.0]
  def change
    create_table :receipts, id: :uuid do |t|
      t.references :warehouse, null: false, foreign_key: true, type: :uuid
      t.references :admin, null: false, foreign_key: true, type: :uuid
      t.string :supplier_name
      t.string :reference_number
      t.date :expected_date
      t.date :received_date
      t.string :status
      t.integer :total_items
      t.integer :received_items
      t.text :notes

      t.timestamps
    end
  end
end
