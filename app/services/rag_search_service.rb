class RagSearchService
  SYSTEM_PROMPT = <<~PROMPT
    You are a helpful assistant that answers questions based on the developer's personal knowledge base.
    Use ONLY the provided context entries to answer. If the context doesn't contain relevant information, say so.
    Reference specific entries when possible. Format code examples with markdown code blocks.
    Keep answers concise and technical.
  PROMPT

  SIMILARITY_THRESHOLD = 0.3

  def initialize(chat)
    @chat = chat
  end

  def ask_sync(question)
    relevant_entries = hybrid_search(question)

    context = build_context(relevant_entries)

    llm_chat = RubyLLM.chat(model: "gpt-4.1-mini", provider: :openai, assume_model_exists: true)
    llm_chat.with_instructions(<<~INSTRUCTIONS)
      #{SYSTEM_PROMPT}

      ## Relevant entries from the knowledge base:

      #{context}
    INSTRUCTIONS

    response = llm_chat.ask(question)

    { response: response.content, sources: relevant_entries }
  end

  def ask(question, &on_chunk)
    relevant_entries = hybrid_search(question)

    context = build_context(relevant_entries)

    llm_chat = RubyLLM.chat(model: "gpt-4.1-mini", provider: :openai, assume_model_exists: true)
    llm_chat.with_instructions(<<~INSTRUCTIONS)
      #{SYSTEM_PROMPT}

      ## Relevant entries from the knowledge base:

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
    Entry.where(id: merged.map(&:id)).includes(:tags).index_by(&:id).values_at(*merged.map(&:id))
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
    Entry.keyword_search(question).includes(:tags).limit(5).to_a
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
    return "No relevant entries found in the knowledge base." if entries.empty?

    entries.map.with_index do |entry, i|
      <<~ENTRY
        ### Entry #{i + 1}: #{entry.title} [#{entry.entry_type.humanize}]
        #{entry.ai_summary}

        #{entry.content.truncate(1000)}

        Tags: #{entry.tags.map(&:name).join(", ")}
        ---
      ENTRY
    end.join("\n")
  end
end
