class AssignCompanyToExistingCategories < ActiveRecord::Migration[8.0]
  def up
    default_company = Company.first
    if default_company
      Category.where(company_id: nil).update_all(company_id: default_company.id)
    end
  end

  def down
    # No action needed
  end
end