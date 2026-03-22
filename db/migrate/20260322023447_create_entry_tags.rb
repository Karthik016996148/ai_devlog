class CreateEntryTags < ActiveRecord::Migration[7.1]
  def change
    create_table :entry_tags do |t|
      t.references :entry, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true
      t.integer :source, null: false, default: 0

      t.timestamps
    end

    add_index :entry_tags, [:entry_id, :tag_id], unique: true
  end
end
