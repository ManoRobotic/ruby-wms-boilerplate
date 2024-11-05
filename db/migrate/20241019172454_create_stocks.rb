class CreateStocks < ActiveRecord::Migration[7.2]
  def change
    create_table :stocks, id: :uuid do |t|
      t.references :product, null: false, foreign_key: true, type: :uuid
      t.integer :amount, default: 0
      t.string :size

      t.timestamps
    end
  end
end
