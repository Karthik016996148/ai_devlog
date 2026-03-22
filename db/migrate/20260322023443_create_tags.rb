class CreateTags < ActiveRecord::Migration[7.1]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.integer :source, null: false, default: 0
      t.integer :entries_count, default: 0

      t.timestamps
    end

    add_index :tags, :name, unique: true
    add_index :tags, :entries_count
  end
end
