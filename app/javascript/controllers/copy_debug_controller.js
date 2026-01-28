import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    recordType: String,
    recordId: Number,
    createdAt: String,
    url: String,
  };

  copy() {
    const text = `${this.recordTypeValue} #${this.recordIdValue}
ID: ${this.recordIdValue}
Created: ${this.createdAtValue}
URL: ${this.urlValue}`;

    navigator.clipboard.writeText(text).then(() => {
      const originalText = this.element.innerHTML;
      this.element.textContent = "Copied!";
      setTimeout(() => {
        this.element.innerHTML = originalText;
      }, 1500);
    });
  }
}
