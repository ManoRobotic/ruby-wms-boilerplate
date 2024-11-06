class CreateOrders < ActiveRecord::Migration[7.2]
  def change
    create_table :orders, id: :uuid do |t|
      t.string :customer_email, null: false 
      t.boolean :fulfilled
      t.integer :total, null: false, default: 0
      t.text :address, null: false

      t.timestamps
    end
  end
end
