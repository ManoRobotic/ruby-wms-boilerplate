class AddWaveToOrdersAndPickLists < ActiveRecord::Migration[8.0]
  def change
    add_reference :orders, :wave, null: true, foreign_key: true, type: :uuid
    add_reference :pick_lists, :wave, null: true, foreign_key: true, type: :uuid
    
    add_index :orders, [:wave_id, :status]
    add_index :pick_lists, [:wave_id, :status]
  end
end
