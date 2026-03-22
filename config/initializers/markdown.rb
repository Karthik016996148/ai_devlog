require "rouge"
require "rouge/plugins/redcarpet"
require "redcarpet"

class CustomMarkdownRenderer < Redcarpet::Render::HTML
  include Rouge::Plugins::Redcarpet
end
