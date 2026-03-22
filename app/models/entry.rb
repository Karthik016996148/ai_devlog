class Entry < ApplicationRecord
  include Embeddable

  has_many :entry_tags, dependent: :destroy
  has_many :tags, through: :entry_tags
  has_many :related_entries_associations, class_name: "RelatedEntry", dependent: :destroy
  has_many :related_entries, through: :related_entries_associations, source: :related_entry

  enum :entry_type, {
    code_snippet: 0,
    error_log: 1,
    solution: 2,
    note: 3,
    til: 4
  }

  enum :processing_status, {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }

  validates :title, presence: true, length: { maximum: 200 }
  validates :content, presence: true
  validates :entry_type, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :processed, -> { where(processing_status: :completed) }
  scope :by_type, ->(type) { where(entry_type: type) }
  scope :tagged_with, ->(tag_name) {
    joins(:tags).where(tags: { name: tag_name })
  }
  scope :keyword_search, ->(query) {
    return none if query.blank?
    keywords = query.strip.split(/\s+/).map { |w| "%#{sanitize_sql_like(w)}%" }
    conditions = keywords.map { "title ILIKE ? OR content ILIKE ? OR ai_summary ILIKE ?" }
    binds = keywords.flat_map { |k| [k, k, k] }
    where(conditions.join(" OR "), *binds)
  }

  after_create_commit :enqueue_ai_processing

  def ai_tags
    tags.where(entry_tags: { source: :ai_generated })
  end

  def manual_tags
    tags.where(entry_tags: { source: :manual })
  end

  private

  def enqueue_ai_processing
    EntryProcessingJob.perform_later(id)
  end
end
