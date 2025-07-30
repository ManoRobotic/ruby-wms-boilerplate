class CreateLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :locations, id: :uuid do |t|
      t.references :zone, null: false, foreign_key: true, type: :uuid
      t.string :aisle, null: false, limit: 10
      t.string :bay, null: false, limit: 10
      t.string :level, null: false, limit: 10
      t.string :position, null: false, limit: 10
      t.string :barcode, limit: 50
      t.string :location_type, null: false, default: 'bin'
      t.integer :capacity, default: 100
      t.integer :current_volume, default: 0
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :locations, :barcode, unique: true, where: "barcode IS NOT NULL"
    add_index :locations, [ :zone_id, :aisle, :bay, :level, :position ], unique: true, name: 'index_locations_on_coordinates'
    add_index :locations, :location_type
    add_index :locations, :active
  end
end
