import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { target: String };

  open() {
    const modal = document.getElementById(this.targetValue);
    if (modal) {
      modal.style.display = "flex";
      document.body.style.overflow = "hidden";
    }
  }

  close() {
    this.element.style.display = "none";
    document.body.style.overflow = "";
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close();
    }
  }

  connect() {
    if (this.element.classList.contains("modal")) {
      document.addEventListener("keydown", this.closeOnEscape.bind(this));
    }
  }

  disconnect() {
    if (this.element.classList.contains("modal")) {
      document.removeEventListener("keydown", this.closeOnEscape.bind(this));
    }
  }
}
