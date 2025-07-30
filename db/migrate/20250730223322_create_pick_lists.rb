class CreatePickLists < ActiveRecord::Migration[8.0]
  def change
    create_table :pick_lists, id: :uuid do |t|
      t.references :admin, null: false, foreign_key: true, type: :uuid
      t.references :order, null: false, foreign_key: true, type: :uuid
      t.references :warehouse, null: false, foreign_key: true, type: :uuid
      t.string :status, null: false, default: 'pending'
      t.string :priority, null: false, default: 'medium'
      t.integer :total_items, default: 0
      t.integer :picked_items, default: 0
      t.datetime :started_at
      t.datetime :completed_at
      t.string :pick_list_number, null: false

      t.timestamps
    end

    add_index :pick_lists, :pick_list_number, unique: true
    add_index :pick_lists, :status
    add_index :pick_lists, :priority
    add_index :pick_lists, :started_at
  end
end
