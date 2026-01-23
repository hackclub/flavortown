import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    count: { type: Number, default: 80 },
    drift: { type: Number, default: 30 },
  };

  // Base star positions (percentage-based)
  baseStars = [
    { x: 5, y: 8 },
    { x: 12, y: 15 },
    { x: 18, y: 5 },
    { x: 25, y: 22 },
    { x: 32, y: 10 },
    { x: 38, y: 28 },
    { x: 45, y: 6 },
    { x: 52, y: 18 },
    { x: 58, y: 32 },
    { x: 65, y: 12 },
    { x: 72, y: 25 },
    { x: 78, y: 8 },
    { x: 85, y: 20 },
    { x: 92, y: 14 },
    { x: 8, y: 35 },
    { x: 15, y: 45 },
    { x: 22, y: 38 },
    { x: 28, y: 52 },
    { x: 35, y: 42 },
    { x: 42, y: 55 },
    { x: 48, y: 40 },
    { x: 55, y: 48 },
    { x: 62, y: 58 },
    { x: 68, y: 44 },
    { x: 75, y: 52 },
    { x: 82, y: 38 },
    { x: 88, y: 48 },
    { x: 95, y: 42 },
    { x: 3, y: 62 },
    { x: 10, y: 72 },
    { x: 17, y: 65 },
    { x: 24, y: 78 },
    { x: 30, y: 68 },
    { x: 37, y: 82 },
    { x: 44, y: 70 },
    { x: 50, y: 75 },
    { x: 57, y: 85 },
    { x: 63, y: 72 },
    { x: 70, y: 80 },
    { x: 77, y: 65 },
    { x: 83, y: 75 },
    { x: 90, y: 68 },
    { x: 96, y: 78 },
    { x: 7, y: 88 },
    { x: 14, y: 92 },
    { x: 20, y: 85 },
    { x: 27, y: 95 },
    { x: 33, y: 88 },
    { x: 40, y: 92 },
    { x: 47, y: 86 },
    { x: 53, y: 94 },
    { x: 60, y: 88 },
    { x: 67, y: 92 },
    { x: 73, y: 86 },
    { x: 80, y: 95 },
    { x: 87, y: 88 },
    { x: 93, y: 92 },
    { x: 2, y: 50 },
    { x: 98, y: 55 },
    { x: 50, y: 3 },
    { x: 50, y: 97 },
    { x: 4, y: 25 },
    { x: 96, y: 30 },
    { x: 11, y: 58 },
    { x: 89, y: 62 },
    { x: 23, y: 12 },
    { x: 77, y: 88 },
    { x: 35, y: 75 },
    { x: 65, y: 25 },
    { x: 42, y: 15 },
    { x: 58, y: 85 },
    { x: 19, y: 70 },
    { x: 81, y: 30 },
    { x: 46, y: 62 },
    { x: 54, y: 38 },
    { x: 29, y: 90 },
    { x: 71, y: 10 },
    { x: 38, y: 58 },
    { x: 62, y: 42 },
  ];

  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      return;
    }

    this.createStarsContainer();
    this.renderStars();
  }

  disconnect() {
    if (this.starsContainer) {
      this.starsContainer.remove();
    }
  }

  createStarsContainer() {
    this.starsContainer = document.createElement("div");
    this.starsContainer.className = "launch-stars";
    this.starsContainer.setAttribute("aria-hidden", "true");
    document.body.appendChild(this.starsContainer);
    this.stars = [];
  }

  renderStars() {
    const drift = this.driftValue;

    this.baseStars.forEach((base, index) => {
      const star = document.createElement("div");
      star.className = "launch-star";

      // Randomize position from base
      const offsetX = (Math.random() - 0.5) * 2 * drift;
      const offsetY = (Math.random() - 0.5) * 2 * drift;
      const x = Math.max(0, Math.min(100, base.x + offsetX));
      const y = Math.max(0, Math.min(100, base.y + offsetY));

      // Random size (small stars)
      const size = Math.random() * 2 + 1;

      // Random opacity
      const opacity = Math.random() * 0.5 + 0.3;

      star.style.cssText = `
        left: ${x}%;
        top: ${y}%;
        width: ${size}px;
        height: ${size}px;
        --base-opacity: ${opacity};
      `;

      this.starsContainer.appendChild(star);
      this.stars.push(star);
    });

    this.startRandomTwinkle();
  }

  startRandomTwinkle() {
    this.twinkleInterval = setInterval(() => {
      // Pick 5-8 random stars to twinkle
      const count = Math.floor(Math.random() * 4) + 5;

      for (let i = 0; i < count; i++) {
        const randomIndex = Math.floor(Math.random() * this.stars.length);
        const star = this.stars[randomIndex];

        if (!star.classList.contains("launch-star--twinkle")) {
          star.classList.add("launch-star--twinkle");

          // Random duration for how long it stays bright
          const duration = Math.random() * 500 + 300;

          setTimeout(() => {
            star.classList.remove("launch-star--twinkle");
          }, duration);
        }
      }
    }, 200);
  }

  disconnect() {
    if (this.twinkleInterval) {
      clearInterval(this.twinkleInterval);
    }
    if (this.starsContainer) {
      this.starsContainer.remove();
    }
  }
}
