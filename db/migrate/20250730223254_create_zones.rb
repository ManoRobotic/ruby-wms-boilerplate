class CreateZones < ActiveRecord::Migration[8.0]
  def change
    create_table :zones, id: :uuid do |t|
      t.references :warehouse, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false, limit: 100
      t.string :code, null: false, limit: 20
      t.string :zone_type, null: false, limit: 50, default: 'general'
      t.text :description

      t.timestamps
    end

    add_index :zones, [ :warehouse_id, :code ], unique: true
    add_index :zones, :zone_type
  end
end
