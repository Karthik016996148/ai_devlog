class RagSearchService
  SYSTEM_PROMPT = <<~PROMPT
    You are a RETRIEVAL-ONLY assistant for a developer's personal knowledge base.

    STRICT RULES:
    1. ONLY use information from the provided entries below. NEVER add your own knowledge or generic advice.
    2. Quote or paraphrase DIRECTLY from the entries. Preserve code blocks exactly as written.
    3. Always cite the source entry by title, e.g. "From **Entry Title**:".
    4. RELEVANCE CHECK: Before using an entry, verify its TITLE and MAIN TOPIC match the question.
       An entry that merely mentions a keyword in passing (e.g. inside code or a side note) is NOT relevant.
       Only use entries whose primary subject matches what the user is asking about.
    5. If no entries are directly relevant, respond ONLY with:
       "No matching entries found in your knowledge base for this query."
    6. Do NOT fill in gaps with outside knowledge. If entries don't fully cover the topic, say so.
  PROMPT

  SIMILARITY_THRESHOLD = 0.2
  MIN_KEYWORD_RELEVANCE = 3

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
    answer = response.content

    cited_sources = filter_cited_sources(answer, relevant_entries)

    { response: answer, sources: cited_sources }
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
    answer = response.respond_to?(:content) ? response.content : response.to_s

    cited_sources = filter_cited_sources(answer, relevant_entries)

    { response: response, sources: cited_sources }
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
    text_matches = Entry.processed.keyword_search(question).limit(5).to_a
    text_matches = text_matches.select do |e|
      e.respond_to?(:keyword_relevance) && e.keyword_relevance.to_i >= MIN_KEYWORD_RELEVANCE
    end

    tag_matches = tag_search(question)
    (text_matches + tag_matches).uniq(&:id).first(5)
  end

  def tag_search(question)
    keywords = question.strip.split(/\s+/).map { |w| w.downcase.gsub(/[^a-z0-9\-]/, "") }.reject(&:blank?)
    return [] if keywords.empty?
    Entry.processed.joins(:tags).where("tags.name IN (?)", keywords).distinct.limit(3).to_a
  end

  def merge_results(vector_results, keyword_results)
    seen_ids = Set.new
    merged = []

    both_ids = vector_results.map(&:id) & keyword_results.map(&:id)
    both = vector_results.select { |e| both_ids.include?(e.id) }
    both.each { |e| seen_ids.add(e.id); merged << e }

    keyword_results.each { |e| next if seen_ids.include?(e.id); seen_ids.add(e.id); merged << e }
    vector_results.each { |e| next if seen_ids.include?(e.id); seen_ids.add(e.id); merged << e }

    merged.first(5)
  end

  def filter_cited_sources(answer, entries)
    return [] if answer.include?("No matching entries found")

    answer_down = answer.downcase
    cited = entries.select do |entry|
      answer_down.include?(entry.title.downcase)
    end

    cited.any? ? cited : entries.first(1)
  end

  def build_context(entries)
    entries.map.with_index do |entry, i|
      <<~ENTRY
        === ENTRY #{i + 1} ===
        Title: "#{entry.title}"
        Type: #{entry.entry_type.humanize}
        Tags: #{entry.tags.map(&:name).join(", ")}
        #{"Summary: #{entry.ai_summary}" if entry.ai_summary.present?}

        Full Content:
        #{entry.content}
        === END ENTRY #{i + 1} ===
      ENTRY
    end.join("\n\n")
  end
end
