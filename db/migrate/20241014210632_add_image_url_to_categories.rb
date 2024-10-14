class AddImageUrlToCategories < ActiveRecord::Migration[7.2]
  def change
    add_column :categories, :image_url, :string
  end
end
