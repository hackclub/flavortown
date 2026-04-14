import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "output"];
  static values = { minWords: { type: Number, default: 10 } };

  connect() {
    this.update();
  }

  update() {
    if (!this.hasInputTarget || !this.hasOutputTarget) return;

    const text = this.inputTarget.value ?? "";
    const count = text.trim() ? text.trim().split(/\s+/).length : 0;
    const min = this.minWordsValue;
    this.outputTarget.textContent = `${count} / ${min} words`;
    this.outputTarget.classList.toggle("word-count--met", count >= min);
  }
}
