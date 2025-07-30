class CreateCycleCountItems < ActiveRecord::Migration[8.0]
  def change
    create_table :cycle_count_items, id: :uuid do |t|
      t.references :cycle_count, null: false, foreign_key: true, type: :uuid
      t.references :product, null: false, foreign_key: true, type: :uuid
      t.integer :system_quantity
      t.integer :counted_quantity
      t.integer :variance
      t.string :status
      t.text :notes

      t.timestamps
    end
  end
end
