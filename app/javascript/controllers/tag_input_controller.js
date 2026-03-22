import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "hidden", "container"]

  connect() {
    const existing = this.hiddenTarget.value
    if (existing) {
      existing.split(",").map(t => t.trim()).filter(Boolean).forEach(tag => {
        this.appendTag(tag)
      })
    }
  }

  add(event) {
    if (event.key === "," || event.key === "Enter") {
      event.preventDefault()
      const tag = this.inputTarget.value.replace(",", "").trim()
      if (tag) {
        this.appendTag(tag)
        this.inputTarget.value = ""
      }
    }
  }

  remove(event) {
    event.target.closest("[data-tag]").remove()
    this.updateHidden()
  }

  appendTag(name) {
    const existing = [...this.containerTarget.querySelectorAll("[data-tag]")]
      .map(el => el.dataset.tag)
    if (existing.includes(name)) return

    const pill = document.createElement("span")
    pill.dataset.tag = name
    pill.className = "inline-flex items-center gap-1 px-2 py-1 bg-indigo-100 text-indigo-800 rounded-full text-sm"
    pill.innerHTML = `${name} <button type="button" data-action="click->tag-input#remove" class="text-indigo-600 hover:text-indigo-900 ml-1">&times;</button>`
    this.containerTarget.appendChild(pill)
    this.updateHidden()
  }

  updateHidden() {
    const tags = [...this.containerTarget.querySelectorAll("[data-tag]")]
      .map(el => el.dataset.tag)
    this.hiddenTarget.value = tags.join(",")
  }
}
