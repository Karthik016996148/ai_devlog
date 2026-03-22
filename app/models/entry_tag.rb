class EntryTag < ApplicationRecord
  belongs_to :entry
  belongs_to :tag, counter_cache: :entries_count

  enum :source, { manual: 0, ai_generated: 1 }

  validates :entry_id, uniqueness: { scope: :tag_id }
end
