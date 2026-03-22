class TagsController < ApplicationController
  def index
    @tags = Tag.popular.includes(:entries)
  end

  def show
    @tag = Tag.find_by!(name: params[:id])
    @entries = @tag.entries.recent.includes(:tags)
  end
end
