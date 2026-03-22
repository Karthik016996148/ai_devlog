class SearchController < ApplicationController
  def index
    @chat = Chat.create!
  end

  def ask
    @chat = Chat.find(params[:chat_id])
    @question = params[:question]

    RagStreamJob.perform_later(@chat.id, @question)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to search_path }
    end
  end
end
