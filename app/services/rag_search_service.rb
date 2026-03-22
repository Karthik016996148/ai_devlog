class RagSearchService
  SYSTEM_PROMPT = <<~PROMPT
    You are a RETRIEVAL-ONLY assistant for a developer's personal knowledge base.

    STRICT RULES:
    1. ONLY use information from the provided entries below. NEVER add your own knowledge.
    2. Quote or paraphrase directly from the entries. Preserve code blocks exactly as they appear.
    3. Always cite the entry by its title, e.g. "From **Entry Title**:".
    4. If no entries are provided or none are relevant to the question, respond ONLY with:
       "No matching entries found in your knowledge base for this query."
    5. Do NOT provide generic advice, suggestions, or information from outside the entries.
    6. If an entry partially matches, present what it contains and note what it doesn't cover.
  PROMPT

  SIMILARITY_THRESHOLD = 0.2

  def initialize(chat)
    @chat = chat
  end

  def ask_sync(question)
    relevant_entries = hybrid_search(question)

    if relevant_entries.empty?
      return {
        response: "No matching entries found in your knowledge base for this query.",
        sources: []
      }
    end

    context = build_context(relevant_entries)

    llm_chat = RubyLLM.chat(model: "gpt-4.1-mini", provider: :openai, assume_model_exists: true)
    llm_chat.with_instructions(<<~INSTRUCTIONS)
      #{SYSTEM_PROMPT}

      ## Retrieved entries from the knowledge base:

      #{context}
    INSTRUCTIONS

    response = llm_chat.ask(question)

    { response: response.content, sources: relevant_entries }
  end

  def ask(question, &on_chunk)
    relevant_entries = hybrid_search(question)

    if relevant_entries.empty?
      return {
        response: "No matching entries found in your knowledge base for this query.",
        sources: []
      }
    end

    context = build_context(relevant_entries)

    llm_chat = RubyLLM.chat(model: "gpt-4.1-mini", provider: :openai, assume_model_exists: true)
    llm_chat.with_instructions(<<~INSTRUCTIONS)
      #{SYSTEM_PROMPT}

      ## Retrieved entries from the knowledge base:

      #{context}
    INSTRUCTIONS

    response = llm_chat.ask(question, &on_chunk)

    { response: response, sources: relevant_entries }
  end

  private

  def hybrid_search(question)
    vector_results = vector_search(question)
    keyword_results = keyword_search(question)

    merged = merge_results(vector_results, keyword_results)
    return [] if merged.empty?

    ids = merged.map(&:id)
    Entry.where(id: ids).includes(:tags).index_by(&:id).values_at(*ids).compact
  end

  def vector_search(question)
    query_result = RubyLLM.embed(question, model: "text-embedding-3-small", provider: :openai, assume_model_exists: true)
    query_embedding = query_result.vectors

    results = Entry.processed.search_by_embedding(query_embedding, limit: 5)
    results.select { |e| e.respond_to?(:similarity_score) && e.similarity_score.to_f >= SIMILARITY_THRESHOLD }
  rescue => e
    Rails.logger.warn("Vector search failed: #{e.message}")
    []
  end

  def keyword_search(question)
    text_matches = Entry.keyword_search(question).limit(5).to_a
    tag_matches = tag_search(question)
    (text_matches + tag_matches).uniq(&:id).first(5)
  end

  def tag_search(question)
    keywords = question.strip.split(/\s+/).map { |w| w.downcase.gsub(/[^a-z0-9\-]/, "") }.reject(&:blank?)
    return [] if keywords.empty?
    Entry.joins(:tags).where("tags.name IN (?)", keywords).distinct.limit(3).to_a
  end

  def merge_results(vector_results, keyword_results)
    seen_ids = Set.new
    merged = []

    both_ids = vector_results.map(&:id) & keyword_results.map(&:id)
    both = vector_results.select { |e| both_ids.include?(e.id) }
    both.each { |e| seen_ids.add(e.id); merged << e }

    vector_results.each { |e| next if seen_ids.include?(e.id); seen_ids.add(e.id); merged << e }
    keyword_results.each { |e| next if seen_ids.include?(e.id); seen_ids.add(e.id); merged << e }

    merged.first(5)
  end

  def build_context(entries)
    entries.map.with_index do |entry, i|
      <<~ENTRY
        === ENTRY #{i + 1} ===
        Title: #{entry.title}
        Type: #{entry.entry_type.humanize}
        Tags: #{entry.tags.map(&:name).join(", ")}

        Content (quote this directly):
        #{entry.content}

        #{"AI Summary: #{entry.ai_summary}" if entry.ai_summary.present?}
        === END ENTRY #{i + 1} ===
      ENTRY
    end.join("\n\n")
  end
end
