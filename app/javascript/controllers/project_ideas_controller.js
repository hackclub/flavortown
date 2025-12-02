import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  toggle() {
    const container = document.getElementById("project-idea-container")
    const overlay = document.getElementById("project-idea-overlay")
    if (container.style.display === "none") {
      container.style.display = "block"
      overlay.style.display = "block"
    } else {
      container.style.display = "none"
      overlay.style.display = "none"
    }
  }
}
