class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks, id: :uuid do |t|
      t.references :admin, null: false, foreign_key: true, type: :uuid
      t.string :task_type, null: false
      t.string :priority, null: false, default: 'medium'
      t.string :status, null: false, default: 'pending'
      t.references :warehouse, null: false, foreign_key: true, type: :uuid
      t.references :location, null: true, foreign_key: true, type: :uuid
      t.references :product, null: true, foreign_key: true, type: :uuid
      t.integer :quantity, default: 1
      t.text :instructions
      t.datetime :assigned_at
      t.datetime :completed_at
      t.references :from_location, null: true, foreign_key: { to_table: :locations }, type: :uuid
      t.references :to_location, null: true, foreign_key: { to_table: :locations }, type: :uuid

      t.timestamps
    end

    add_index :tasks, :task_type
    add_index :tasks, :status
    add_index :tasks, :priority
    add_index :tasks, :assigned_at
  end
end
