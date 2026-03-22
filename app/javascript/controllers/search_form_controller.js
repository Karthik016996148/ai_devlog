import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button"]

  connect() {
    this.boundReset = this.reset.bind(this)
    this.element.addEventListener("turbo:submit-end", this.boundReset)
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-end", this.boundReset)
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

    const chatMessages = document.getElementById("chat_messages")
    if (chatMessages) {
      requestAnimationFrame(() => {
        chatMessages.scrollTop = chatMessages.scrollHeight
      })
    }
  }
}
