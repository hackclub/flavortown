import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    document.body.style.overflow = 'hidden';
  }

  disconnect() {
    document.body.style.overflow = '';
  }

  close(e) {
    if (e) e.preventDefault()
    this.element.remove()
  }

  closeBackground(e) {
    if (e.target === this.element) {
      this.close(e)
    }
  }

  closeWithEsc(e) {
    if (e.key === "Escape") {
      this.close(e)
    }
  }
}