class RagSearchService
  def initialize(chat)
    @chat = chat
  end

  def ask_sync(question)
    entries = search_entries(question)

    if entries.empty?
      return { response: "No matching entries found for \"#{question}\".", sources: [] }
    end

    answer = generate_answer(question, entries)
    { response: answer, sources: entries }
  end

  private

  def search_entries(question)
    words = question.strip.split(/\s+/).reject { |w| w.length < 2 }.uniq.map(&:downcase)
    return [] if words.empty?

    patterns = words.map { |w| "%#{Entry.sanitize_sql_like(w)}%" }

    conditions = patterns.map { "(title ILIKE ? OR content ILIKE ? OR ai_summary ILIKE ?)" }
    binds = patterns.flat_map { |p| [p, p, p] }

    Entry.where(conditions.join(" OR "), *binds)
         .includes(:tags)
         .limit(5)
         .to_a
  end

  def generate_answer(question, entries)
    context = entries.map do |e|
      "Title: \"#{e.title}\"\nContent:\n#{e.content}"
    end.join("\n---\n")

    llm = RubyLLM.chat(model: "gpt-4.1-mini", provider: :openai, assume_model_exists: true)
    llm.with_instructions(<<~INST)
      You retrieve information from a developer's knowledge base.
      ONLY use the entries below. Cite each by title. Never add outside knowledge.
      If entries don't answer the question, present what they contain.

      ## Entries:
      #{context}
    INST

    llm.ask(question).content
  rescue => e
    Rails.logger.error("LLM failed: #{e.message}")
    entries.map { |e| "**#{e.title}**\n\n#{e.content}" }.join("\n\n---\n\n")
  end
end
