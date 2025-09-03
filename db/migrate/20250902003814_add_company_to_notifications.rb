class AddCompanyToNotifications < ActiveRecord::Migration[8.0]
  def change
    add_reference :notifications, :company, null: false, foreign_key: true, type: :uuid
  end
end
