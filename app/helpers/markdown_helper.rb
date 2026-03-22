module MarkdownHelper
  def render_markdown(text)
    return "".html_safe if text.blank?

    renderer = CustomMarkdownRenderer.new(hard_wrap: true)
    markdown = Redcarpet::Markdown.new(renderer,
      fenced_code_blocks: true,
      autolink: true,
      tables: true,
      strikethrough: true,
      no_intra_emphasis: true
    )

    sanitize(markdown.render(text),
      tags: %w[p br h1 h2 h3 h4 h5 h6 ul ol li a code pre strong em blockquote table thead tbody tr th td span div],
      attributes: %w[href class style]
    ).html_safe
  end
end
