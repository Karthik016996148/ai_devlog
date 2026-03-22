class SearchController < ApplicationController
  def index
    @chat = Chat.create!
  end

  def ask
    @chat = Chat.find(params[:chat_id])
    @question = params[:question]

    service = RagSearchService.new(@chat)
    @result = service.ask_sync(@question)
    @answer = @result[:response]
    @sources = @result[:sources]

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to search_path }
    end
  rescue => e
    @answer = "Error: #{e.message}"
    @sources = []
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to search_path, alert: e.message }
    end
  end
end
