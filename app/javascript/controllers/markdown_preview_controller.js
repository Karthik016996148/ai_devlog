import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "editButton", "previewButton"]

  connect() {
    this.showEdit()
  }

  showEdit() {
    this.inputTarget.classList.remove("hidden")
    this.previewTarget.classList.add("hidden")
    this.editButtonTarget.classList.add("bg-indigo-100", "text-indigo-700")
    this.editButtonTarget.classList.remove("text-gray-500")
    this.previewButtonTarget.classList.remove("bg-indigo-100", "text-indigo-700")
    this.previewButtonTarget.classList.add("text-gray-500")
  }

  showPreview() {
    const content = this.inputTarget.querySelector("textarea")?.value || ""
    if (content.trim() === "") {
      this.previewTarget.innerHTML = '<p class="text-gray-400 italic">Nothing to preview</p>'
    } else {
      this.previewTarget.innerHTML = this.simpleMarkdown(content)
    }
    this.inputTarget.classList.add("hidden")
    this.previewTarget.classList.remove("hidden")
    this.previewButtonTarget.classList.add("bg-indigo-100", "text-indigo-700")
    this.previewButtonTarget.classList.remove("text-gray-500")
    this.editButtonTarget.classList.remove("bg-indigo-100", "text-indigo-700")
    this.editButtonTarget.classList.add("text-gray-500")
  }

  simpleMarkdown(text) {
    let html = text
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")

    html = html.replace(/```(\w*)\n([\s\S]*?)```/g, (_, lang, code) => {
      return `<pre class="bg-gray-100 rounded-md p-3 overflow-x-auto text-sm"><code>${code.trim()}</code></pre>`
    })

    html = html.replace(/`([^`]+)`/g, '<code class="bg-gray-100 rounded px-1 py-0.5 text-sm">$1</code>')
    html = html.replace(/^### (.+)$/gm, '<h3 class="text-base font-semibold mt-3 mb-1">$1</h3>')
    html = html.replace(/^## (.+)$/gm, '<h2 class="text-lg font-semibold mt-4 mb-2">$1</h2>')
    html = html.replace(/^# (.+)$/gm, '<h1 class="text-xl font-bold mt-4 mb-2">$1</h1>')
    html = html.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
    html = html.replace(/\*(.+?)\*/g, "<em>$1</em>")
    html = html.replace(/\n/g, "<br>")

    return html
  }
}
