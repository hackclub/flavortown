import { Controller } from "@hotwired/stimulus";
import { gsap } from "gsap";
import { MotionPathPlugin } from "gsap/MotionPathPlugin";

gsap.registerPlugin(MotionPathPlugin);

export default class extends Controller {
  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    this.scheduleNext();
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout);
  }

  scheduleNext() {
    const delay = 3200 + Math.random() * 5200;
    this.timeout = setTimeout(() => {
      this.launch();
      this.scheduleNext();
    }, delay);
  }

  launch() {
    const width = this.element.clientWidth;
    const height = this.element.clientHeight;
    if (width < 40 || height < 40) return;

    const fromLeft = Math.random() > 0.5;
    const startX = fromLeft ? -18 : width + 18;
    const startY = Math.random() * height * 0.3;
    const endX = fromLeft ? width + 36 : -36;
    const endY = height * 0.45 + Math.random() * height * 0.4;
    const curveX = (startX + endX) / 2;
    const curveY = (startY + endY) / 2 - (Math.random() * 24 + 10);
    const duration = 1.2 + Math.random() * 0.9;

    const star = document.createElement("div");
    star.className = "shooting-star shooting-star--card";
    star.setAttribute("aria-hidden", "true");
    this.element.appendChild(star);

    gsap.set(star, {
      left: 0,
      top: 0,
      x: startX,
      y: startY,
      opacity: 1,
    });

    const tl = gsap.timeline({ onComplete: () => star.remove() });
    tl.to(
      star,
      {
        duration,
        ease: "none",
        motionPath: {
          path: `M ${startX},${startY} Q ${curveX},${curveY} ${endX},${endY}`,
          autoRotate: true,
        },
      },
      0,
    );
    tl.to(
      star,
      {
        duration,
        opacity: 0,
        ease: "power1.in",
      },
      0,
    );
  }
}
