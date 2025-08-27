class AddEmpresaToUsers < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :empresa, null: true, foreign_key: true, type: :uuid
  end
end
