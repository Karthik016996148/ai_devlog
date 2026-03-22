class RagStreamJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 2

  def perform(chat_id, question)
    chat = Chat.find(chat_id)
    service = RagSearchService.new(chat)

    result = service.ask(question) do |chunk|
      if chunk.content.present?
        Turbo::StreamsChannel.broadcast_append_to(
          "chat_#{chat.id}",
          target: "chat_#{chat.id}_response",
          html: ERB::Util.html_escape(chunk.content).gsub("\n", "<br>")
        )
      end
    end

    sources = result[:sources]
    if sources.present?
      sources_html = ApplicationController.render(
        partial: "search/sources",
        locals: { entries: sources }
      )
      Turbo::StreamsChannel.broadcast_replace_to(
        "chat_#{chat.id}",
        target: "chat_#{chat.id}_sources",
        html: sources_html
      )
    end

    Turbo::StreamsChannel.broadcast_replace_to(
      "chat_#{chat.id}",
      target: "chat_#{chat.id}_thinking",
      html: "<div id=\"chat_#{chat.id}_thinking\"></div>"
    )
  rescue => e
    Turbo::StreamsChannel.broadcast_replace_to(
      "chat_#{chat_id}",
      target: "chat_#{chat_id}_thinking",
      html: "<div id=\"chat_#{chat_id}_thinking\" class=\"text-sm text-red-600 py-2\">Error: #{ERB::Util.html_escape(e.message)}</div>"
    )
    raise
  end
end
