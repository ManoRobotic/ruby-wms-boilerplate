class CreateOrderProducts < ActiveRecord::Migration[7.2]
  def change
    create_table :order_products, id: :uuid do |t|
      t.references :product, null: false, foreign_key: true, type: :uuid
      t.references :order, null: false, foreign_key: true, type: :uuid
      t.string :size, null: false
      t.integer :quantity, null: false, default: 1

      t.timestamps
    end
  end
end
