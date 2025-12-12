import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["content"];
  static values = { text: Array };

  connect() {
    this.index = 0;
    this.#render();
  }

  next(event) {
    event?.preventDefault?.();
    event?.stopPropagation?.();

    const lines = Array.isArray(this.textValue) ? this.textValue : [];
    if (lines.length === 0) return this.close();

    const nextIndex = this.index + 1;
    if (nextIndex >= lines.length) return this.close();

    this.index = nextIndex;
    this.#render();
  }

  close() {
    const backdrop = this.element.previousElementSibling;
    if (backdrop?.classList?.contains("dialogue-box-backdrop")) {
      backdrop.remove();
    }
    this.element.remove();
  }

  #render() {
    if (!this.hasContentTarget) return;
    const line = this.textValue?.[this.index] ?? "";
    this.contentTarget.textContent = line;
  }
}