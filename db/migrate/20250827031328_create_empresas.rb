class CreateEmpresas < ActiveRecord::Migration[8.0]
  def change
    create_table :empresas, id: :uuid do |t|
      t.string :name

      t.timestamps
    end
  end
end
