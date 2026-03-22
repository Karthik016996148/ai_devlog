class RagSearchService
  SYSTEM_PROMPT = <<~PROMPT
    You are a helpful assistant that answers questions based on the developer's personal knowledge base.
    Use ONLY the provided context entries to answer. If the context doesn't contain relevant information, say so.
    Reference specific entries when possible. Format code examples with markdown code blocks.
    Keep answers concise and technical.
  PROMPT

  def initialize(chat)
    @chat = chat
  end

  def ask_sync(question)
    query_result = RubyLLM.embed(question, model: "text-embedding-3-small", provider: :openai, assume_model_exists: true)
    query_embedding = query_result.vectors

    relevant_entries = Entry.processed.search_by_embedding(query_embedding, limit: 5).includes(:tags)

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
    query_result = RubyLLM.embed(question, model: "text-embedding-3-small", provider: :openai, assume_model_exists: true)
    query_embedding = query_result.vectors

    relevant_entries = Entry.processed.search_by_embedding(query_embedding, limit: 5).includes(:tags)

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
