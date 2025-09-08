class AddCompanyToCategories < ActiveRecord::Migration[8.0]
  def change
    add_reference :categories, :company, null: true, foreign_key: true, type: :uuid
  end
end
