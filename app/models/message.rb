class Message < ApplicationRecord
  acts_as_message
  has_many_attached :attachments

  scope :ordered, -> { order(created_at: :asc) }
end
