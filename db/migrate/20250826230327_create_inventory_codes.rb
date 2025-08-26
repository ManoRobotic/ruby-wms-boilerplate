class CreateInventoryCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :inventory_codes, id: :uuid do |t|
      t.string :no_ordp, null: false
      t.string :cve_copr
      t.string :cve_prod
      t.decimal :can_copr, precision: 12, scale: 6
      t.integer :tip_copr
      t.decimal :costo, precision: 12, scale: 8
      t.date :fech_cto
      t.string :cve_suc
      t.integer :trans
      t.string :lote
      t.string :new_med
      t.string :new_copr
      t.decimal :costo_rep, precision: 12, scale: 8
      t.integer :partresp
      t.string :dmov
      t.integer :partop
      t.decimal :fcdres, precision: 12, scale: 6
      t.string :undres

      t.timestamps
    end

    add_index :inventory_codes, :no_ordp
    add_index :inventory_codes, :cve_prod
    add_index :inventory_codes, :cve_copr
    add_index :inventory_codes, :lote
    add_index :inventory_codes, :fech_cto
  end
end
