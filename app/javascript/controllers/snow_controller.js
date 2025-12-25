import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    selectors: {
      type: String,
      default:
        ".card, .btn, .sidebar, .sidebar__user-card, .sidebar__nav-link--active, .container, .state-card, .project-card, .kitchen-help-card",
    },
    chance: {
      type: Number,
      default: 0.7,
    },
  };

  connect() {
    this.snowLayers = [];
    this.snowflakes = [];
    this.addSnowToElements();
    this.createFallingSnow();
    this.resizeHandler = () => this.updateSnowPositions();
    window.addEventListener("resize", this.resizeHandler);
  }

  disconnect() {
    window.removeEventListener("resize", this.resizeHandler);
    this.snowLayers.forEach((layer) => {
      layer.removeEventListener("mouseenter", layer._disperseHandler);
      layer.remove();
    });
    this.snowLayers = [];
    if (this.snowContainer) {
      this.snowContainer.remove();
    }
    this.snowflakes = [];
  }

  addSnowToElements() {
    const elements = document.querySelectorAll(this.selectorsValue);

    elements.forEach((el) => {
      if (el.closest(".snow-layer")) return;
      if (getComputedStyle(el).display === "none") return;
      if (el.offsetWidth < 20 || el.offsetHeight < 20) return;
      if (Math.random() > this.chanceValue) return;

      const rect = el.getBoundingClientRect();
      if (rect.width === 0 || rect.height === 0) return;

      const style = getComputedStyle(el);
      const position = style.position;

      if (position === "static") {
        el.style.position = "relative";
      }

      const snowLayer = document.createElement("div");
      snowLayer.className = "snow-layer";
      snowLayer.setAttribute("aria-hidden", "true");

      const snowCount = Math.max(3, Math.floor(rect.width / 15));
      for (let i = 0; i < snowCount; i++) {
        const snowPile = document.createElement("div");
        snowPile.className = "snow-pile";
        snowPile.style.left = `${(i / snowCount) * 100}%`;
        snowPile.style.animationDelay = `${Math.random() * 2}s`;
        snowLayer.appendChild(snowPile);
      }

      snowLayer._disperseHandler = (e) => this.disperseSnow(e, snowLayer);
      snowLayer.style.pointerEvents = "auto";
      snowLayer.addEventListener("mouseenter", snowLayer._disperseHandler);

      el.appendChild(snowLayer);
      this.snowLayers.push(snowLayer);
    });
  }

  disperseSnow(event, snowLayer) {
    const piles = snowLayer.querySelectorAll(".snow-pile");
    piles.forEach((pile) => {
      const randomX = (Math.random() - 0.5) * 40;
      pile.style.setProperty("--disperse-x", `${randomX}px`);
      pile.classList.add("snow-pile--dispersing");
    });

    setTimeout(() => {
      piles.forEach((pile) => {
        pile.classList.remove("snow-pile--dispersing");
        pile.style.animation = "none";
        pile.offsetHeight;
        pile.style.animation = "";
      });
    }, 2000);
  }

  updateSnowPositions() {
    this.snowLayers.forEach((layer) => {
      layer.removeEventListener("mouseenter", layer._disperseHandler);
      layer.remove();
    });
    this.snowLayers = [];
    this.addSnowToElements();
  }

  createFallingSnow() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      return;
    }

    this.snowContainer = document.createElement("div");
    this.snowContainer.className = "falling-snow-container";
    this.snowContainer.setAttribute("aria-hidden", "true");
    document.body.appendChild(this.snowContainer);

    const snowflakeCount = 50;
    for (let i = 0; i < snowflakeCount; i++) {
      this.createSnowflake();
    }
  }

  createSnowflake() {
    const snowflake = document.createElement("div");
    snowflake.className = "falling-snowflake";

    const size = Math.random() * 8 + 3;
    const startX = Math.random() * 100;
    const duration = Math.random() * 15 + 10;
    const delay = Math.random() * -20;
    const drift = (Math.random() - 0.5) * 100;
    const opacity = Math.random() * 0.6 + 0.4;
    const blur = Math.random() > 0.7 ? Math.random() * 2 : 0;

    snowflake.style.cssText = `
      width: ${size}px;
      height: ${size}px;
      left: ${startX}%;
      animation-duration: ${duration}s;
      animation-delay: ${delay}s;
      opacity: ${opacity};
      filter: blur(${blur}px);
      --drift: ${drift}px;
    `;

    if (Math.random() > 0.7) {
      snowflake.classList.add("falling-snowflake--star");
    }

    this.snowContainer.appendChild(snowflake);
    this.snowflakes.push(snowflake);
  }
}
