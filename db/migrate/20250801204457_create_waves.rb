class CreateWaves < ActiveRecord::Migration[8.0]
  def change
    create_table :waves, id: :uuid do |t|
      t.string :name, null: false
      t.references :warehouse, null: false, foreign_key: true, type: :uuid
      t.string :status, null: false, default: 'planning'
      t.string :wave_type, null: false, default: 'standard'
      t.integer :priority, default: 5
      t.datetime :planned_start_time
      t.datetime :actual_start_time
      t.datetime :actual_end_time
      t.integer :total_orders, default: 0
      t.integer :total_items, default: 0
      t.string :strategy, default: 'zone_based'
      t.text :notes
      t.references :admin, null: true, foreign_key: true, type: :uuid

      t.timestamps
    end

    add_index :waves, [ :warehouse_id, :status ]
    add_index :waves, [ :status, :planned_start_time ]
    add_index :waves, :priority
  end
end
