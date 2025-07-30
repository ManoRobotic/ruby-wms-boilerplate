class CreateCycleCounts < ActiveRecord::Migration[8.0]
  def change
    create_table :cycle_counts, id: :uuid do |t|
      t.references :warehouse, null: false, foreign_key: true, type: :uuid
      t.references :admin, null: false, foreign_key: true, type: :uuid
      t.references :location, null: false, foreign_key: true, type: :uuid
      t.string :status
      t.date :scheduled_date
      t.date :completed_date
      t.string :count_type
      t.text :notes

      t.timestamps
    end
  end
end
