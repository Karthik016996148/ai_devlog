import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.querySelectorAll("pre").forEach(pre => {
      const wrapper = document.createElement("div")
      wrapper.className = "relative group"
      pre.parentNode.insertBefore(wrapper, pre)
      wrapper.appendChild(pre)

      const btn = document.createElement("button")
      btn.className = "absolute top-2 right-2 hidden group-hover:inline-flex items-center rounded bg-gray-700 px-2 py-1 text-xs text-white hover:bg-gray-600"
      btn.textContent = "Copy"
      btn.addEventListener("click", () => {
        const code = pre.querySelector("code")?.innerText || pre.innerText
        navigator.clipboard.writeText(code).then(() => {
          btn.textContent = "Copied!"
          setTimeout(() => { btn.textContent = "Copy" }, 2000)
        })
      })
      wrapper.appendChild(btn)
    })
  }
}
