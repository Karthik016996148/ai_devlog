class Chat < ApplicationRecord
  acts_as_chat

  scope :recent, -> { order(updated_at: :desc) }
end
