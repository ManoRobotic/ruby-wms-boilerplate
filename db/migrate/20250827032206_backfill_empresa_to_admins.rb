class BackfillEmpresaToAdmins < ActiveRecord::Migration[8.0]
  def up
    # Ensure models are loaded
    Empresa.reset_column_information
    Admin.reset_column_information

    flexiempaques_empresa = Empresa.find_by(name: "flexiempaques")
    rzavala_empresa = Empresa.find_by(name: "rzavala")

    if flexiempaques_empresa
      Admin.where(super_admin_role: "flexiempaques").update_all(empresa_id: flexiempaques_empresa.id)
    end

    if rzavala_empresa
      Admin.where(super_admin_role: "rzavala").update_all(empresa_id: rzavala_empresa.id)
    end

    # For 'global' admins, you might assign them to a default company or leave empresa_id nil
    # if they are not tied to a specific company.
    # Example: Admin.where(super_admin_role: "global").update_all(empresa_id: some_default_empresa.id)
  end

  def down
    # Optional: If you need to revert this data change, define the logic here.
    # For example, set all empresa_id to nil:
    # Admin.update_all(empresa_id: nil)
  end
end