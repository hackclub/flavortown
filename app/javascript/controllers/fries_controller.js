import { Controller } from "@hotwired/stimulus";

const FRIES_EMOJIS = ["🍟", "🍔", "🍦", "🥤", "🍎"];

export default class extends Controller {
  connect() {
    this.fries = [];
    this.createFallingFries();
  }

  disconnect() {
    if (this.friesContainer) {
      this.friesContainer.remove();
    }
    this.fries = [];
  }

  createFallingFries() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      return;
    }

    this.friesContainer = document.createElement("div");
    this.friesContainer.className = "falling-fries-container";
    this.friesContainer.setAttribute("aria-hidden", "true");
    document.body.appendChild(this.friesContainer);

    const friesCount = 30;
    for (let i = 0; i < friesCount; i++) {
      this.createFry();
    }
  }

  createFry() {
    const fry = document.createElement("div");
    fry.className = "falling-fry";

    const emoji = FRIES_EMOJIS[Math.floor(Math.random() * FRIES_EMOJIS.length)];
    fry.textContent = emoji;

    const startX = Math.random() * 100;
    const duration = Math.random() * 12 + 8;
    const delay = Math.random() * -25;
    const drift = (Math.random() - 0.5) * 120;
    const size = Math.random() * 0.8 + 0.8;

    fry.style.cssText = `
      left: ${startX}%;
      font-size: ${size}rem;
      animation-duration: ${duration}s;
      animation-delay: ${delay}s;
      --drift: ${drift}px;
    `;

    this.friesContainer.appendChild(fry);
    this.fries.push(fry);
  }
}
