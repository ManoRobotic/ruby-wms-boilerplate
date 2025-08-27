class BackfillEmpresaToWarehouses < ActiveRecord::Migration[8.0]
  def up
    # Ensure Empresa model is loaded
    Empresa.reset_column_information
    Warehouse.reset_column_information

    flexiempaques_empresa = Empresa.find_by(name: "flexiempaques")
    rzavala_empresa = Empresa.find_by(name: "rzavala")

    if flexiempaques_empresa
      Warehouse.where(name: "Almacén FlexiEmpaques").update_all(empresa_id: flexiempaques_empresa.id)
    end

    if rzavala_empresa
      Warehouse.where(name: "Almacén R.Zavala").update_all(empresa_id: rzavala_empresa.id)
    end

    # Assign a default company to any remaining warehouses if necessary,
    # or leave them null if that's acceptable for other warehouses.
    # For example, assign to flexiempaques if no other company is found:
    # Warehouse.where(empresa_id: nil).update_all(empresa_id: flexiempaques_empresa.id) if flexiempaques_empresa
  end

  def down
    # Optional: If you need to revert this data change, define the logic here.
    # For example, set all empresa_id to nil:
    # Warehouse.update_all(empresa_id: nil)
  end
end