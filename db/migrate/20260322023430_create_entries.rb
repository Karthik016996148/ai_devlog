class CreateEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :entries do |t|
      t.string :title, null: false
      t.text :content, null: false
      t.integer :entry_type, null: false, default: 0
      t.text :ai_summary
      t.integer :processing_status, null: false, default: 0
      t.text :processing_error
      t.jsonb :embedding, default: nil

      t.timestamps
    end

    add_index :entries, :entry_type
    add_index :entries, :processing_status
    add_index :entries, :created_at
  end
end
