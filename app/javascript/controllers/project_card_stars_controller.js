import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    if (!this.element.classList.contains("project-card--space-themed")) return;
    this.renderStars();
  }

  renderStars() {
    this.element.querySelector(".project-card__stars")?.remove();

    const layer = document.createElement("div");
    layer.className = "project-card__stars";

    const count = this.randomInt(16, 28);
    for (let i = 0; i < count; i += 1) {
      const star = document.createElement("span");
      star.className = "project-card__star";

      star.style.setProperty("--x", `${Math.random() * 100}%`);
      star.style.setProperty("--y", `${Math.random() * 100}%`);
      star.style.setProperty("--size", `${(Math.random() * 2.4 + 1.2).toFixed(2)}px`);
      star.style.setProperty("--twinkle-delay", `${(Math.random() * 2.5).toFixed(2)}s`);
      star.style.setProperty("--twinkle-duration", `${(Math.random() * 2 + 1.8).toFixed(2)}s`);
      star.style.setProperty("--opacity", `${(Math.random() * 0.35 + 0.55).toFixed(2)}`);

      layer.appendChild(star);
    }

    this.element.prepend(layer);
  }

  randomInt(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
  }
}
