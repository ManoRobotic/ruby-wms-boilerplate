class AddImageUrlToProduct < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :image_url, :string
  end
end
