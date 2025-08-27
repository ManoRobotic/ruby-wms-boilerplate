class BackfillEmpresaToUsers < ActiveRecord::Migration[8.0]
  def up
    # Actualizar users con empresa_id basado en su warehouse
    User.joins(:warehouse).where(users: { empresa_id: nil }).find_each do |user|
      user.update_column(:empresa_id, user.warehouse.empresa_id) if user.warehouse&.empresa_id
    end
  end

  def down
    # En la reversión, simplemente ponemos empresa_id a nil
    User.where.not(empresa_id: nil).update_all(empresa_id: nil)
  end
end
