import { Controller } from "@hotwired/stimulus";

// Four-pointed star SVG path generator
// Creates the diamond-cross star shape from the Figma design
function createStarPath(cx, cy, size) {
  // Four-pointed star with curved inner edges
  const s = size / 2;
  return `M${cx} ${cy - s} C${cx} ${cy - s} ${cx + s * 0.15} ${cy - s * 0.4} ${cx + s * 0.35} ${cy - s * 0.35} C${cx + s * 0.55} ${cy - s * 0.3} ${cx + s} ${cy} ${cx + s} ${cy} C${cx + s} ${cy} ${cx + s * 0.55} ${cy + s * 0.3} ${cx + s * 0.35} ${cy + s * 0.35} C${cx + s * 0.15} ${cy + s * 0.4} ${cx} ${cy + s} ${cx} ${cy + s} C${cx} ${cy + s} ${cx - s * 0.15} ${cy + s * 0.4} ${cx - s * 0.35} ${cy + s * 0.35} C${cx - s * 0.55} ${cy + s * 0.3} ${cx - s} ${cy} ${cx - s} ${cy} C${cx - s} ${cy} ${cx - s * 0.55} ${cy - s * 0.3} ${cx - s * 0.35} ${cy - s * 0.35} C${cx - s * 0.15} ${cy - s * 0.4} ${cx} ${cy - s} ${cx} ${cy - s}Z`;
}

export default class extends Controller {
  static values = {
    drift: { type: Number, default: 15 },
  };

  // Star configurations by size category
  // Based on Figma: large (50-65px), medium (35-50px), small (20-35px), tiny (10-20px)
  starConfigs = [
    // Large stars - slow drift, prominent glow (6 total)
    { x: 5, y: 15, size: "large", color: "#F2F9FF" },
    { x: 75, y: 8, size: "large", color: "#FFF2FA" },
    { x: 45, y: 75, size: "large", color: "#F2F3FF" },
    { x: 88, y: 55, size: "large", color: "#F2F9FF" },
    { x: 30, y: 40, size: "large", color: "#FFF2FA" },
    { x: 60, y: 20, size: "large", color: "#F2F3FF" },

    // Medium stars (14 total)
    { x: 12, y: 35, size: "medium", color: "#FFF2FA" },
    { x: 32, y: 10, size: "medium", color: "#F2F3FF" },
    { x: 58, y: 42, size: "medium", color: "#F2F9FF" },
    { x: 82, y: 28, size: "medium", color: "#FFF2FA" },
    { x: 25, y: 68, size: "medium", color: "#F2F3FF" },
    { x: 68, y: 85, size: "medium", color: "#F2F9FF" },
    { x: 92, y: 72, size: "medium", color: "#FFF2FA" },
    { x: 40, y: 5, size: "medium", color: "#F2F9FF" },
    { x: 15, y: 55, size: "medium", color: "#FFF2FA" },
    { x: 55, y: 65, size: "medium", color: "#F2F3FF" },
    { x: 78, y: 12, size: "medium", color: "#F2F9FF" },
    { x: 3, y: 80, size: "medium", color: "#FFF2FA" },
    { x: 95, y: 38, size: "medium", color: "#F2F3FF" },
    { x: 48, y: 88, size: "medium", color: "#F2F9FF" },

    // Small stars (20 total)
    { x: 8, y: 48, size: "small", color: "#FFF2FA" },
    { x: 22, y: 22, size: "small", color: "#F2F3FF" },
    { x: 38, y: 55, size: "small", color: "#FFF2FA" },
    { x: 52, y: 18, size: "small", color: "#F2F9FF" },
    { x: 65, y: 62, size: "small", color: "#FFF2FA" },
    { x: 78, y: 40, size: "small", color: "#F2F3FF" },
    { x: 15, y: 82, size: "small", color: "#FFF2FA" },
    { x: 42, y: 92, size: "small", color: "#F2F9FF" },
    { x: 95, y: 15, size: "small", color: "#FFF2FA" },
    { x: 85, y: 88, size: "small", color: "#F2F3FF" },
    { x: 2, y: 12, size: "small", color: "#F2F9FF" },
    { x: 33, y: 78, size: "small", color: "#FFF2FA" },
    { x: 72, y: 32, size: "small", color: "#F2F3FF" },
    { x: 18, y: 45, size: "small", color: "#F2F9FF" },
    { x: 88, y: 65, size: "small", color: "#FFF2FA" },
    { x: 58, y: 8, size: "small", color: "#F2F3FF" },
    { x: 28, y: 95, size: "small", color: "#F2F9FF" },
    { x: 82, y: 5, size: "small", color: "#FFF2FA" },
    { x: 5, y: 58, size: "small", color: "#F2F3FF" },
    { x: 62, y: 78, size: "small", color: "#F2F9FF" },

    // Tiny stars - fast twinkle (40 total for dense starfield)
    { x: 3, y: 25, size: "tiny", color: "#FFF2FA" },
    { x: 18, y: 5, size: "tiny", color: "#F2F3FF" },
    { x: 28, y: 45, size: "tiny", color: "#FFF2FA" },
    { x: 35, y: 30, size: "tiny", color: "#F2F9FF" },
    { x: 48, y: 58, size: "tiny", color: "#FFF2FA" },
    { x: 55, y: 8, size: "tiny", color: "#F2F3FF" },
    { x: 62, y: 32, size: "tiny", color: "#FFF2FA" },
    { x: 72, y: 52, size: "tiny", color: "#F2F9FF" },
    { x: 80, y: 18, size: "tiny", color: "#FFF2FA" },
    { x: 88, y: 38, size: "tiny", color: "#F2F3FF" },
    { x: 10, y: 62, size: "tiny", color: "#FFF2FA" },
    { x: 20, y: 88, size: "tiny", color: "#F2F9FF" },
    { x: 50, y: 72, size: "tiny", color: "#FFF2FA" },
    { x: 70, y: 95, size: "tiny", color: "#F2F3FF" },
    { x: 98, y: 45, size: "tiny", color: "#FFF2FA" },
    { x: 5, y: 95, size: "tiny", color: "#F2F9FF" },
    { x: 38, y: 3, size: "tiny", color: "#FFF2FA" },
    { x: 92, y: 82, size: "tiny", color: "#F2F3FF" },
    { x: 7, y: 38, size: "tiny", color: "#F2F9FF" },
    { x: 14, y: 72, size: "tiny", color: "#FFF2FA" },
    { x: 24, y: 15, size: "tiny", color: "#F2F3FF" },
    { x: 32, y: 62, size: "tiny", color: "#F2F9FF" },
    { x: 44, y: 28, size: "tiny", color: "#FFF2FA" },
    { x: 56, y: 48, size: "tiny", color: "#F2F3FF" },
    { x: 64, y: 12, size: "tiny", color: "#F2F9FF" },
    { x: 76, y: 68, size: "tiny", color: "#FFF2FA" },
    { x: 84, y: 25, size: "tiny", color: "#F2F3FF" },
    { x: 96, y: 58, size: "tiny", color: "#F2F9FF" },
    { x: 2, y: 48, size: "tiny", color: "#FFF2FA" },
    { x: 12, y: 8, size: "tiny", color: "#F2F3FF" },
    { x: 26, y: 52, size: "tiny", color: "#F2F9FF" },
    { x: 36, y: 85, size: "tiny", color: "#FFF2FA" },
    { x: 46, y: 42, size: "tiny", color: "#F2F3FF" },
    { x: 54, y: 22, size: "tiny", color: "#F2F9FF" },
    { x: 66, y: 75, size: "tiny", color: "#FFF2FA" },
    { x: 74, y: 5, size: "tiny", color: "#F2F3FF" },
    { x: 86, y: 48, size: "tiny", color: "#F2F9FF" },
    { x: 94, y: 92, size: "tiny", color: "#FFF2FA" },
    { x: 8, y: 85, size: "tiny", color: "#F2F3FF" },
    { x: 42, y: 65, size: "tiny", color: "#F2F9FF" },
  ];

  sizeMap = {
    large: { min: 45, max: 60, blur: 15, opacity: 0.9 },
    medium: { min: 30, max: 42, blur: 10, opacity: 0.8 },
    small: { min: 18, max: 28, blur: 6, opacity: 0.7 },
    tiny: { min: 10, max: 16, blur: 3, opacity: 0.6 },
  };

  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      return;
    }

    this.createStarsContainer();
    this.renderStars();
    this.setupScrollFade();
  }

  setupScrollFade() {
    this.boundHandleScroll = this.handleScroll.bind(this);
    window.addEventListener("scroll", this.boundHandleScroll, {
      passive: true,
    });
    this.handleScroll();
  }

  handleScroll() {
    if (!this.svgContainer) return;

    const scrollY = window.scrollY;
    const fadeStart = 100;
    const fadeEnd = 400;

    let opacity = 1;
    if (scrollY > fadeStart) {
      opacity = Math.max(0, 1 - (scrollY - fadeStart) / (fadeEnd - fadeStart));
    }

    this.svgContainer.style.opacity = String(opacity);
  }

  createStarsContainer() {
    // Create SVG container for vector stars
    this.svgContainer = document.createElementNS(
      "http://www.w3.org/2000/svg",
      "svg",
    );
    this.svgContainer.setAttribute("class", "launch-stars-svg");
    this.svgContainer.setAttribute("aria-hidden", "true");
    this.svgContainer.setAttribute("viewBox", "0 0 100 100");
    this.svgContainer.setAttribute("preserveAspectRatio", "xMidYMid slice");
    // Start hidden, fade in after render
    this.svgContainer.style.opacity = "0";
    this.svgContainer.style.transition = "opacity 1s ease-in";

    // Create defs for filters (glow effects)
    const defs = document.createElementNS("http://www.w3.org/2000/svg", "defs");

    // Create glow filters for each size
    ["large", "medium", "small", "tiny"].forEach((size) => {
      const filter = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "filter",
      );
      filter.setAttribute("id", `glow-${size}`);
      filter.setAttribute("x", "-100%");
      filter.setAttribute("y", "-100%");
      filter.setAttribute("width", "300%");
      filter.setAttribute("height", "300%");

      const feGaussianBlur = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "feGaussianBlur",
      );
      feGaussianBlur.setAttribute(
        "stdDeviation",
        String(this.sizeMap[size].blur / 100),
      );
      feGaussianBlur.setAttribute("result", "coloredBlur");

      const feMerge = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "feMerge",
      );
      const feMergeNode1 = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "feMergeNode",
      );
      feMergeNode1.setAttribute("in", "coloredBlur");
      const feMergeNode2 = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "feMergeNode",
      );
      feMergeNode2.setAttribute("in", "SourceGraphic");

      feMerge.appendChild(feMergeNode1);
      feMerge.appendChild(feMergeNode2);
      filter.appendChild(feGaussianBlur);
      filter.appendChild(feMerge);
      defs.appendChild(filter);
    });

    this.svgContainer.appendChild(defs);
    document.body.appendChild(this.svgContainer);
    this.stars = [];
  }

  renderStars() {
    const drift = this.driftValue;

    this.starConfigs.forEach((config, index) => {
      const sizeConfig = this.sizeMap[config.size];

      // Randomize position slightly
      const offsetX = (Math.random() - 0.5) * drift;
      const offsetY = (Math.random() - 0.5) * drift;
      const x = Math.max(2, Math.min(98, config.x + offsetX));
      const y = Math.max(2, Math.min(98, config.y + offsetY));

      // Random size within range (as percentage of viewBox)
      const size =
        (Math.random() * (sizeConfig.max - sizeConfig.min) + sizeConfig.min) /
        100;

      // Create star group
      const group = document.createElementNS("http://www.w3.org/2000/svg", "g");
      group.setAttribute(
        "class",
        `launch-star-group launch-star--${config.size}`,
      );
      group.style.transformOrigin = `${x}% ${y}%`;

      // Create outer glow star (larger, blurred)
      const glowPath = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "path",
      );
      glowPath.setAttribute("d", createStarPath(x, y, size * 1.8));
      glowPath.setAttribute("fill", config.color);
      glowPath.setAttribute("opacity", String(sizeConfig.opacity * 0.4));
      glowPath.setAttribute("filter", `url(#glow-${config.size})`);
      glowPath.setAttribute("class", "launch-star-glow");

      // Create inner star (sharp)
      const starPath = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "path",
      );
      starPath.setAttribute("d", createStarPath(x, y, size));
      starPath.setAttribute("fill", config.color);
      starPath.setAttribute("opacity", String(sizeConfig.opacity));
      starPath.setAttribute("class", "launch-star-core");

      group.appendChild(glowPath);
      group.appendChild(starPath);
      this.svgContainer.appendChild(group);

      this.stars.push({
        element: group,
        size: config.size,
        baseOpacity: sizeConfig.opacity,
      });
    });

    // Fade in stars after a brief delay
    requestAnimationFrame(() => {
      this.svgContainer.style.opacity = "1";
    });

    this.startAnimations();
  }

  startAnimations() {
    // Different twinkle speeds for different sizes
    const twinkleSpeeds = {
      large: { interval: 4000, duration: 1500 },
      medium: { interval: 3000, duration: 1000 },
      small: { interval: 2000, duration: 800 },
      tiny: { interval: 1500, duration: 500 },
    };

    this.twinkleIntervals = [];

    // Start twinkle animations per size category
    Object.entries(twinkleSpeeds).forEach(([size, timing]) => {
      const interval = setInterval(() => {
        const starsOfSize = this.stars.filter((s) => s.size === size);
        const count = Math.ceil(starsOfSize.length * 0.3); // Twinkle 30% at a time

        for (let i = 0; i < count; i++) {
          const randomIndex = Math.floor(Math.random() * starsOfSize.length);
          const star = starsOfSize[randomIndex];

          if (!star.element.classList.contains("launch-star--twinkle")) {
            star.element.classList.add("launch-star--twinkle");

            setTimeout(() => {
              star.element.classList.remove("launch-star--twinkle");
            }, timing.duration);
          }
        }
      }, timing.interval);

      this.twinkleIntervals.push(interval);
    });
  }

  disconnect() {
    if (this.twinkleIntervals) {
      this.twinkleIntervals.forEach((interval) => clearInterval(interval));
    }
    if (this.boundHandleScroll) {
      window.removeEventListener("scroll", this.boundHandleScroll);
    }
    if (this.svgContainer) {
      this.svgContainer.remove();
    }
  }
}
