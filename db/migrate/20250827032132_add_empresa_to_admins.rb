class AddEmpresaToAdmins < ActiveRecord::Migration[8.0]
  def change
    add_reference :admins, :empresa, null: true, foreign_key: true, type: :uuid
  end
end
