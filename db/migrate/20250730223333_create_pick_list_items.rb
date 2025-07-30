class CreatePickListItems < ActiveRecord::Migration[8.0]
  def change
    create_table :pick_list_items, id: :uuid do |t|
      t.references :pick_list, null: false, foreign_key: true, type: :uuid
      t.references :product, null: false, foreign_key: true, type: :uuid
      t.references :location, null: false, foreign_key: true, type: :uuid
      t.integer :quantity_requested, null: false
      t.integer :quantity_picked, default: 0
      t.string :status, null: false, default: 'pending'
      t.integer :sequence, null: false
      t.string :size

      t.timestamps
    end

    add_index :pick_list_items, [ :pick_list_id, :sequence ]
    add_index :pick_list_items, :status
  end
end
