import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  submit(event) {
    event.preventDefault()
    const question = this.inputTarget.value.trim()
    if (question === "") return

    this.element.requestSubmit()
    this.inputTarget.value = ""
    this.inputTarget.focus()
  }
}
