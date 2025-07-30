class CreateWarehouses < ActiveRecord::Migration[8.0]
  def change
    create_table :warehouses, id: :uuid do |t|
      t.string :name, null: false, limit: 100
      t.string :code, null: false, limit: 20
      t.text :address, null: false
      t.boolean :active, default: true, null: false
      t.jsonb :contact_info, default: {}

      t.timestamps
    end

    add_index :warehouses, :code, unique: true
    add_index :warehouses, :active
  end
end
