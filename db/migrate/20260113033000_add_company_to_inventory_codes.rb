class AddCompanyToInventoryCodes < ActiveRecord::Migration[7.0]
  def change
    add_reference :inventory_codes, :company, type: :uuid, foreign_key: true, null: true
  end
end
