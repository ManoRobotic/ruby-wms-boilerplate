class AddSpecsToPackingRecords < ActiveRecord::Migration[8.0]
  def change
    add_column :packing_records, :micras, :integer
    add_column :packing_records, :ancho_mm, :integer
  end
end
