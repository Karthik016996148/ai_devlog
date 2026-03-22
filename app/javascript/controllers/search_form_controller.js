import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button"]

  connect() {
    this.element.addEventListener("turbo:submit-end", this.reset.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-end", this.reset.bind(this))
  }

  submit(event) {
    const question = this.inputTarget.value.trim()
    if (question === "") {
      event.preventDefault()
      return
    }
  }

  reset() {
    this.inputTarget.value = ""
    this.inputTarget.disabled = false
    if (this.hasButtonTarget) this.buttonTarget.disabled = false
    this.inputTarget.focus()
  }
}
