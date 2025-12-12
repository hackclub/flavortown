import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  fill(event) {
    const reason = event.currentTarget.dataset.reason
    const textarea = this.element.closest("form").querySelector("textarea")
    if (textarea) {
      textarea.value = reason
    }
  }
}
