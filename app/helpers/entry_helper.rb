module EntryHelper
  ENTRY_TYPE_COLORS = {
    "code_snippet" => "bg-purple-100 text-purple-800",
    "error_log" => "bg-red-100 text-red-800",
    "solution" => "bg-green-100 text-green-800",
    "note" => "bg-blue-100 text-blue-800",
    "til" => "bg-yellow-100 text-yellow-800"
  }.freeze

  ENTRY_TYPE_ICONS = {
    "code_snippet" => "{ }",
    "error_log" => "!",
    "solution" => "\u2713",
    "note" => "\u270E",
    "til" => "\u2605"
  }.freeze

  def entry_type_badge(entry_type)
    css = ENTRY_TYPE_COLORS[entry_type] || "bg-gray-100 text-gray-800"
    icon = ENTRY_TYPE_ICONS[entry_type] || ""
    content_tag(:span, class: "inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium #{css}") do
      concat content_tag(:span, icon, class: "font-mono")
      concat entry_type.humanize
    end
  end

  def processing_status_icon(status)
    case status.to_s
    when "pending"
      content_tag(:span, "\u23F2", class: "text-yellow-500", title: "Queued for processing")
    when "processing"
      content_tag(:span, "\u21BB", class: "animate-spin text-blue-500", title: "AI is processing")
    when "completed"
      content_tag(:span, "\u2713", class: "text-green-500", title: "Processing complete")
    when "failed"
      content_tag(:span, "\u2717", class: "text-red-500", title: "Processing failed")
    end
  end
end
