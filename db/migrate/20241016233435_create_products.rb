class CreateProducts < ActiveRecord::Migration[7.2]
  def change
    create_table :products, id: :uuid do |t|
      t.string :name, null: false
      t.text :description, null: false
      t.integer :price, null: false, default: 0
      t.references :category, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
