import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      return;
    }

    this.scheduleShootingStar();
  }

  scheduleShootingStar() {
    // Random interval between shooting stars: 8-20 seconds
    const delay = 8000 + Math.random() * 12000;

    this.timeout = setTimeout(() => {
      this.createShootingStar();
      this.scheduleShootingStar();
    }, delay);
  }

  createShootingStar() {
    const shootingStar = document.createElement("div");
    shootingStar.className = "shooting-star";

    // Random starting position in top-right quadrant
    const startX = 50 + Math.random() * 50;
    const startY = Math.random() * 30;

    shootingStar.style.left = `${startX}%`;
    shootingStar.style.top = `${startY}%`;

    // Random angle (going down-left, between 200-250 degrees)
    const angle = 200 + Math.random() * 50;
    shootingStar.style.setProperty("--angle", `${angle}deg`);

    this.element.appendChild(shootingStar);

    // Animate across screen
    shootingStar.animate(
      [
        { transform: "translate(0, 0) rotate(var(--angle))", opacity: 1 },
        {
          transform: "translate(-200px, 150px) rotate(var(--angle))",
          opacity: 0,
        },
      ],
      {
        duration: 1000 + Math.random() * 500,
        easing: "ease-out",
      },
    ).onfinish = () => shootingStar.remove();
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout);
    }
  }
}
