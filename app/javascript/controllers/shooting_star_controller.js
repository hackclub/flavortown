import { Controller } from "@hotwired/stimulus";
import { gsap } from "gsap";
import { MotionPathPlugin } from "gsap/MotionPathPlugin";

gsap.registerPlugin(MotionPathPlugin);

export default class extends Controller {
  connect() {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      return;
    }

    this.createShootingStar();
    // Launch one immediately after a short delay
    setTimeout(() => this.launchShootingStar(), 2000);
    this.scheduleNext();
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout);
    }
    if (this.shootingStar) {
      this.shootingStar.remove();
    }
  }

  scheduleNext() {
    // Random interval between shooting stars: 8-20 seconds
    const delay = Math.random() * 12000 + 8000;
    this.timeout = setTimeout(() => {
      this.launchShootingStar();
      this.scheduleNext();
    }, delay);
  }

  createShootingStar() {
    this.shootingStar = document.createElement("div");
    this.shootingStar.className = "shooting-star";
    this.shootingStar.setAttribute("aria-hidden", "true");
    document.body.appendChild(this.shootingStar);
  }

  launchShootingStar() {
    const vw = window.innerWidth;
    const vh = window.innerHeight;

    // Randomly choose: start from top-left going to bottom-right, or top-right going to bottom-left
    const fromLeft = Math.random() > 0.5;

    let startX, startY, endX, endY, curveX, curveY;

    if (fromLeft) {
      // Start from top-left area
      startX = -50;
      startY = Math.random() * vh * 0.3;
      // End at bottom-right area
      endX = vw + 100;
      endY = vh * 0.5 + Math.random() * vh * 0.4;
    } else {
      // Start from top-right area
      startX = vw + 50;
      startY = Math.random() * vh * 0.3;
      // End at bottom-left area
      endX = -100;
      endY = vh * 0.5 + Math.random() * vh * 0.4;
    }

    // Subtle curve - control point slightly above the straight line
    curveX = (startX + endX) / 2;
    curveY = (startY + endY) / 2 - (Math.random() * 80 + 40);

    const duration = 2.5 + Math.random() * 1.5;

    // Calculate initial rotation angle
    const angle = Math.atan2(endY - startY, endX - startX) * (180 / Math.PI);

    // Reset position and make visible
    gsap.set(this.shootingStar, {
      left: 0,
      top: 0,
      x: startX,
      y: startY,
      opacity: 1,
      rotation: angle,
    });

    // Create timeline for coordinated animations
    const tl = gsap.timeline();

    // Animate along the curved path
    tl.to(
      this.shootingStar,
      {
        duration: duration,
        ease: "none",
        motionPath: {
          path: `M ${startX},${startY} Q ${curveX},${curveY} ${endX},${endY}`,
          autoRotate: true,
        },
      },
      0,
    );

    // Fade out gradually
    tl.to(
      this.shootingStar,
      {
        duration: duration,
        opacity: 0,
        ease: "power1.in",
      },
      0,
    );
  }
}
