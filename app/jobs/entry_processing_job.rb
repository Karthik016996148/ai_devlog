class EntryProcessingJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(entry_id)
    entry = Entry.find(entry_id)
    entry.update!(processing_status: :processing)
    broadcast_status(entry, "processing", "AI is analyzing your entry...")

    # Step 1: Generate summary
    summary = generate_summary(entry)
    entry.update!(ai_summary: summary)
    broadcast_status(entry, "processing", "Summary generated. Extracting tags...")

    # Step 2: Generate tags
    tag_names = generate_tags(entry)
    apply_tags(entry, tag_names)
    broadcast_status(entry, "processing", "Tags applied. Creating embedding...")

    # Step 3: Generate embedding
    embedding = generate_embedding(entry)
    entry.update!(embedding: embedding)
    broadcast_status(entry, "processing", "Finding related entries...")

    # Step 4: Find and store related entries
    find_related_entries(entry)

    # Done
    entry.update!(processing_status: :completed)
    broadcast_status(entry, "completed", "Processing complete!")
    broadcast_entry_update(entry)
  rescue => e
    entry = Entry.find_by(id: entry_id)
    if entry
      entry.update!(processing_status: :failed, processing_error: e.message)
      broadcast_status(entry, "failed", "Processing failed: #{e.message}")
    end
    raise
  end

  private

  def generate_summary(entry)
    chat = RubyLLM.chat(model: "gpt-4.1-mini", assume_model_exists: true)
    response = chat.ask(<<~PROMPT)
      Summarize this developer #{entry.entry_type.humanize.downcase} in 1-2 concise sentences.
      Focus on the key technical insight or solution.

      Title: #{entry.title}
      Content:
      #{entry.content.truncate(3000)}
    PROMPT
    response.content
  end

  def generate_tags(entry)
    chat = RubyLLM.chat(model: "gpt-4.1-mini", assume_model_exists: true)
    response = chat.ask(<<~PROMPT)
      Generate 3-7 relevant tags for this developer #{entry.entry_type.humanize.downcase}.
      Return ONLY a comma-separated list of lowercase tags. No explanations.
      Tags should be specific technical terms (e.g., "postgresql", "n+1-query", "docker", "activerecord").

      Title: #{entry.title}
      Content:
      #{entry.content.truncate(3000)}
    PROMPT
    response.content.split(",").map(&:strip).reject(&:blank?)
  end

  def apply_tags(entry, tag_names)
    tag_names.each do |name|
      normalized = name.downcase.gsub(/\s+/, "-").gsub(/[^a-z0-9\-]/, "")
      next if normalized.blank?
      tag = Tag.find_or_initialize_by(name: normalized)
      tag.source = :ai_generated if tag.new_record?
      tag.save!
      entry.entry_tags.find_or_create_by!(tag: tag, source: :ai_generated)
    end
  end

  def generate_embedding(entry)
    text = "#{entry.title}\n#{entry.content}\n#{entry.ai_summary}"
    result = RubyLLM.embed(text.truncate(8000), model: "text-embedding-3-small", assume_model_exists: true)
    result.vectors
  end

  def find_related_entries(entry)
    return if entry.embedding.nil?

    similar = entry.similar_records(limit: 5)
    similar.each do |related|
      score = related.respond_to?(:similarity_score) ? related.similarity_score : 0.0
      entry.related_entries_associations.find_or_create_by!(related_entry: related) do |re|
        re.similarity_score = score
      end
    end
  end

  def broadcast_status(entry, status, message)
    Turbo::StreamsChannel.broadcast_replace_to(
      "entry_#{entry.id}_processing",
      target: "entry_#{entry.id}_status",
      partial: "entries/processing_status",
      locals: { entry: entry, status: status, message: message }
    )
  end

  def broadcast_entry_update(entry)
    Turbo::StreamsChannel.broadcast_replace_to(
      "entries_list",
      target: "entry_#{entry.id}",
      partial: "entries/entry_card",
      locals: { entry: entry }
    )
  end
end
