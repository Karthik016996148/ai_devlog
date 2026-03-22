class EntriesController < ApplicationController
  before_action :set_entry, only: [:show, :edit, :update, :destroy, :reprocess]

  def index
    @entries = Entry.recent.includes(:tags)
    @entries = @entries.by_type(params[:type]) if params[:type].present?
    @entries = @entries.tagged_with(params[:tag]) if params[:tag].present?
  end

  def show
    @related_entries = @entry.similar_records(limit: 5)
  end

  def new
    @entry = Entry.new
  end

  def create
    @entry = Entry.new(entry_params)

    respond_to do |format|
      if @entry.save
        apply_manual_tags
        format.html { redirect_to @entry, notice: "Entry created! AI processing started." }
        format.turbo_stream { redirect_to @entry, notice: "Entry created! AI processing started." }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def update
    respond_to do |format|
      if @entry.update(entry_params)
        apply_manual_tags
        if @entry.saved_change_to_content? || @entry.saved_change_to_title?
          @entry.update!(processing_status: :pending)
          EntryProcessingJob.perform_later(@entry.id)
        end
        format.html { redirect_to @entry, notice: "Entry updated." }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @entry.destroy
    respond_to do |format|
      format.html { redirect_to entries_path, notice: "Entry deleted." }
      format.turbo_stream
    end
  end

  def reprocess
    @entry.update!(processing_status: :pending)
    EntryProcessingJob.perform_now(@entry.id)
    @entry.reload
    respond_to do |format|
      format.html { redirect_to @entry, notice: "Processing complete!" }
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace(
          "entry_#{@entry.id}_status",
          partial: "entries/processing_status",
          locals: { entry: @entry, status: @entry.processing_status, message: nil }
        )
      }
    end
  rescue => e
    @entry.reload
    respond_to do |format|
      format.html { redirect_to @entry, alert: "Processing failed: #{e.message}" }
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace(
          "entry_#{@entry.id}_status",
          partial: "entries/processing_status",
          locals: { entry: @entry, status: "failed", message: "Failed: #{e.message}" }
        )
      }
    end
  end

  private

  def set_entry
    @entry = Entry.find(params[:id])
  end

  def entry_params
    params.require(:entry).permit(:title, :content, :entry_type)
  end

  def apply_manual_tags
    manual_tags = params.dig(:entry, :manual_tags)
    return unless manual_tags.present?

    tag_names = manual_tags.split(",").map(&:strip).reject(&:blank?)
    tag_names.each do |name|
      tag = Tag.find_or_create_by!(name: name.downcase.gsub(/\s+/, "-"))
      @entry.entry_tags.find_or_create_by!(tag: tag, source: :manual)
    end
  end
end
