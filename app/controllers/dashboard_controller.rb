class DashboardController < ApplicationController
  def index
    @recent_entries = Entry.recent.includes(:tags).limit(10)
    @popular_tags = Tag.cloud
    @entry_counts = {
      total: Entry.count,
      code_snippets: Entry.code_snippet.count,
      error_logs: Entry.error_log.count,
      solutions: Entry.solution.count,
      notes: Entry.note.count,
      tils: Entry.til.count
    }
    @processing_count = Entry.where(processing_status: [:pending, :processing]).count
  end
end
