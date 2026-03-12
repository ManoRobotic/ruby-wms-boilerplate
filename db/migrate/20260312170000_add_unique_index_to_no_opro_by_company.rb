class AddUniqueIndexToNoOproByCompany < ActiveRecord::Migration[8.0]
  def change
    # Remove the old unique index on no_opro (if exists)
    remove_index :production_orders, :no_opro if index_exists?(:production_orders, :no_opro)
    
    # Add new unique index scoped to company_id
    # This allows multiple companies to have the same no_opro values
    add_index :production_orders, [:company_id, :no_opro], unique: true, name: 'index_production_orders_on_company_and_no_opro'
  end
end
