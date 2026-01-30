import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    storageKey: { type: String, default: "debug-mode-enabled" },
  };

  connect() {
    if (localStorage.getItem(this.storageKeyValue) === "true") {
      document.body.classList.add("debug-mode");
    }
  }

  toggle() {
    const isEnabled = document.body.classList.toggle("debug-mode");
    localStorage.setItem(this.storageKeyValue, isEnabled);
  }
}
