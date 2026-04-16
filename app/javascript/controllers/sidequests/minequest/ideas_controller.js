import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "content", "button"]
  static values = { url: String }

  open(e) {
    e.preventDefault()
    this.dialogTarget.classList.remove("hidden")
  }

  close(e) {
    e.preventDefault()
    this.dialogTarget.classList.add("hidden")
  }

  async generate(e) {
    e.preventDefault()
    const originalText = this.contentTarget.innerHTML
    
    this.buttonTarget.disabled = true
    this.buttonTarget.textContent = "Loading..."
    this.contentTarget.innerHTML = "<p>Generating idea with Gemma 3 27B...</p>"

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken
        }
      })
      const data = await response.json()
      
      this.contentTarget.innerHTML = `<p>${data.idea || "No idea generated."}</p>`
    } catch (err) {
      this.contentTarget.innerHTML = "<p>Failed to connect to the server.</p>"
    } finally {
      this.buttonTarget.disabled = false
      this.buttonTarget.textContent = "Generate Idea"
    }
  }
}
