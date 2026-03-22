class CreateRelatedEntries < ActiveRecord::Migration[7.1]
  def change
    create_table :related_entries do |t|
      t.references :entry, null: false, foreign_key: true
      t.references :related_entry, null: false, foreign_key: { to_table: :entries }
      t.float :similarity_score, null: false

      t.timestamps
    end

    add_index :related_entries, [:entry_id, :related_entry_id], unique: true
  end
end
