class RagSearchService
  SYSTEM_PROMPT = <<~PROMPT
    You are a RETRIEVAL-ONLY system for a developer's personal knowledge base.

    RULES:
    1. ONLY present information from the entries provided below.
    2. Quote directly from entries. Preserve code blocks exactly.
    3. Cite each entry you use by its exact title: "From **Title**:"
    4. Check each entry's TITLE — only use it if the title is directly about the question topic.
       Ignore entries that just happen to contain a search keyword inside code or unrelated text.
    5. If none of the entries are relevant, say exactly: "No matching entries found."
    6. NEVER add your own knowledge, advice, or information not in the entries.
  PROMPT

  SIMILARITY_THRESHOLD = 0.3

  def initialize(chat)
    @chat = chat
  end

  def ask_sync(question)
    relevant_entries = find_relevant_entries(question)

    if relevant_entries.empty?
      return { response: "No matching entries found in your knowledge base for this query.", sources: [] }
    end

    context = build_context(relevant_entries)

    llm_chat = RubyLLM.chat(model: "gpt-4.1-mini", provider: :openai, assume_model_exists: true)
    llm_chat.with_instructions("#{SYSTEM_PROMPT}\n\n## Entries:\n\n#{context}")

    answer = llm_chat.ask(question).content

    sources = extract_cited_sources(answer, relevant_entries)

    { response: answer, sources: sources }
  end

  private

  def find_relevant_entries(question)
    vector_ids = vector_search(question).map(&:id)
    keyword_hits = keyword_search(question)
    keyword_ids = keyword_hits.map(&:id)

    seen = Set.new
    ordered_ids = []

    both = keyword_ids & vector_ids
    both.each { |id| seen.add(id); ordered_ids << id }

    keyword_ids.each { |id| next if seen.include?(id); seen.add(id); ordered_ids << id }
    vector_ids.each { |id| next if seen.include?(id); seen.add(id); ordered_ids << id }

    ordered_ids = ordered_ids.first(5)
    return [] if ordered_ids.empty?

    Entry.where(id: ordered_ids).includes(:tags).index_by(&:id).values_at(*ordered_ids).compact
  end

  def vector_search(question)
    embedding = RubyLLM.embed(question, model: "text-embedding-3-small", provider: :openai, assume_model_exists: true).vectors
    results = Entry.processed.search_by_embedding(embedding, limit: 5)
    results.select { |e| e.respond_to?(:similarity_score) && e.similarity_score.to_f >= SIMILARITY_THRESHOLD }
  rescue => e
    Rails.logger.warn("Vector search failed: #{e.message}")
    []
  end

  def keyword_search(question)
    words = question.strip.split(/\s+/).reject { |w| w.length < 3 }.uniq
    return [] if words.empty?

    patterns = words.map { |w| "%#{Entry.sanitize_sql_like(w)}%" }

    title_hits = Entry.where(
      words.map { "title ILIKE ?" }.join(" OR "), *patterns
    ).limit(5).to_a

    tag_names = words.map { |w| w.downcase.gsub(/[^a-z0-9\-]/, "") }.reject(&:blank?)
    tag_hits = if tag_names.any?
      Entry.joins(:tags).where("tags.name IN (?)", tag_names).distinct.limit(3).to_a
    else
      []
    end

    (title_hits + tag_hits).uniq(&:id)
  end

  def extract_cited_sources(answer, entries)
    lower_answer = answer.downcase

    if lower_answer.include?("no matching entries found")
      return []
    end

    cited = entries.select { |e| lower_answer.include?(e.title.downcase) }

    cited
  end

  def build_context(entries)
    entries.map.with_index do |entry, i|
      parts = []
      parts << "=== ENTRY #{i + 1} ==="
      parts << "Title: \"#{entry.title}\""
      parts << "Type: #{entry.entry_type.humanize}"
      parts << "Tags: #{entry.tags.map(&:name).join(', ')}"
      parts << "Summary: #{entry.ai_summary}" if entry.ai_summary.present?
      parts << ""
      parts << entry.content
      parts << "=== END ==="
      parts.join("\n")
    end.join("\n\n")
  end
end
