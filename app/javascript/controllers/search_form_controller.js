import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button"]

  submit(event) {
    const question = this.inputTarget.value.trim()
    if (question === "") {
      event.preventDefault()
      return
    }

    this.inputTarget.disabled = true
    if (this.hasButtonTarget) this.buttonTarget.disabled = true

    setTimeout(() => {
      this.inputTarget.value = ""
      this.inputTarget.disabled = false
      if (this.hasButtonTarget) this.buttonTarget.disabled = false
      this.inputTarget.focus()
    }, 100)
  }
}
