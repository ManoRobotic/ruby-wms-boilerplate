class RemoveForeignKeyConstraintFromTasks < ActiveRecord::Migration[8.0]
  def change
    # Remove the foreign key constraint to allow admin_id to reference either admins or users
    remove_foreign_key :tasks, :admins if foreign_key_exists?(:tasks, :admins)
  end
end
