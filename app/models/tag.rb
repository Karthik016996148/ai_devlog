class Tag < ApplicationRecord
  has_many :entry_tags, dependent: :destroy
  has_many :entries, through: :entry_tags

  enum :source, { manual: 0, ai_generated: 1 }

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  scope :popular, -> { order(entries_count: :desc) }
  scope :cloud, -> { popular.limit(30) }

  before_validation :normalize_name

  private

  def normalize_name
    self.name = name&.strip&.downcase&.gsub(/\s+/, "-")
  end
end
