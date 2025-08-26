class CreateProductionOrderItems < ActiveRecord::Migration[8.0]
  def change
    create_table :production_order_items, id: :uuid do |t|
      t.references :production_order, null: false, foreign_key: true, type: :uuid
      t.string :folio_consecutivo
      t.decimal :peso_bruto
      t.decimal :peso_neto
      t.decimal :metros_lineales
      t.integer :peso_core_gramos
      t.string :status
      t.integer :micras
      t.integer :ancho_mm
      t.integer :altura_cm

      t.timestamps
    end
  end
end
