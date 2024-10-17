class AddActiveStatusToProducts < ActiveRecord::Migration[7.2]
  def change
    add_column :products, :active, :boolean, default: false
  end
end
