class AddPricesToCoins < ActiveRecord::Migration[8.0]
  def change
    add_column :coins, :selling_price, :decimal
    add_column :coins, :purchase_price, :decimal
  end
end
