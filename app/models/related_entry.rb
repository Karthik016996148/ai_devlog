class RelatedEntry < ApplicationRecord
  belongs_to :entry
  belongs_to :related_entry, class_name: "Entry"

  validates :entry_id, uniqueness: { scope: :related_entry_id }
end
