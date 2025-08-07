class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :title, null: false
      t.text :message, null: false
      t.string :notification_type, null: false
      t.datetime :read_at
      t.text :data
      t.string :action_url

      t.timestamps
    end

    add_index :notifications, :notification_type
    add_index :notifications, :read_at
    add_index :notifications, :created_at
  end
end
