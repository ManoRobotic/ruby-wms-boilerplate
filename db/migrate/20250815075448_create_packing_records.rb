class CreatePackingRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :packing_records, id: :uuid do |t|
      t.string :lote_padre
      t.string :lote
      t.string :cve_prod
      t.decimal :peso_bruto, precision: 10, scale: 3
      t.decimal :peso_neto, precision: 10, scale: 3
      t.decimal :metros_lineales, precision: 10, scale: 2
      t.string :nombre
      t.references :production_order, null: false, foreign_key: true, type: :uuid
      t.integer :consecutivo
      t.string :descripcion
      t.string :cliente
      t.string :num_orden

      t.timestamps
    end
    
    add_index :packing_records, :lote_padre
    add_index :packing_records, :lote
    add_index :packing_records, :cve_prod
    add_index :packing_records, [:production_order_id, :consecutivo]
  end
end
