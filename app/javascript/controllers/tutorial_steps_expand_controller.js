import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    autoExpand: Boolean,
    delay: { type: Number, default: 500 },
  };

  connect() {
    // Always render collapsed first so expansion is delayed.
    this.element.open = false;

    if (!this.autoExpandValue) return;

    this.timeout = window.setTimeout(() => {
      this.element.open = true;
    }, this.delayValue);
  }

  disconnect() {
    if (this.timeout) {
      window.clearTimeout(this.timeout);
      this.timeout = null;
    }
  }
}
