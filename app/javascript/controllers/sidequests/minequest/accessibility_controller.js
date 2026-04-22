import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["image", "button"];
  static values = {
    gif: String,
    png: String,
  };

  connect() {
    this.storageKey = "minequest_animation";
    const pref = localStorage.getItem(this.storageKey);
    if (pref === "off") {
      this.disable();
    } else {
      this.enable();
    }
    this.updateButton();
  }

  toggle() {
    const pref = localStorage.getItem(this.storageKey);
    if (pref === "off") {
      localStorage.setItem(this.storageKey, "on");
      this.enable();
    } else {
      localStorage.setItem(this.storageKey, "off");
      this.disable();
    }
    this.updateButton();
  }

  enable() {
    if (!this.hasImageTarget) return;
    this.imageTarget.src = this.gifValue;
    this.imageTarget.dataset.animated = "true";
  }

  disable() {
    if (!this.hasImageTarget) return;
    this.imageTarget.src = this.pngValue;
    this.imageTarget.dataset.animated = "false";
  }

  updateButton() {
    if (!this.hasButtonTarget) return;
    const isOff = localStorage.getItem(this.storageKey) === "off";
    const label = isOff ? "Turn Animation On" : "Turn Animation Off";

    // Keep icon-based buttons intact and expose state via accessibility attributes.
    this.buttonTarget.setAttribute("aria-label", label);
    this.buttonTarget.setAttribute("title", label);

    // Preserve legacy behavior for text buttons that don't contain an icon.
    if (!this.buttonTarget.querySelector("img")) {
      this.buttonTarget.textContent = isOff ? "A11y: Off" : "A11y: On";
    }
    this.buttonTarget.setAttribute("aria-pressed", isOff ? "true" : "false");
  }
}
