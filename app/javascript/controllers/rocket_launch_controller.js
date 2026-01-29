import { Controller } from "@hotwired/stimulus";
import { gsap } from "gsap";

// Rocket launch animation controller
// Triggers when user clicks the /launch link in sidebar
export default class extends Controller {
  static targets = ["rocket"];

  launch(event) {
    // Prevent immediate navigation
    event.preventDefault();

    const rocket = document.getElementById("rocket-launch");
    const targetUrl = event.currentTarget.href;

    if (!rocket) {
      // No rocket element, just navigate
      window.location.href = targetUrl;
      return;
    }

    // Get viewport dimensions
    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;

    // Random deviation for varied trajectory each time
    const startOffsetX = this.randomBetween(-150, 150);
    const startOffsetY = this.randomBetween(-100, 100);
    const endOffsetX = this.randomBetween(-300, 300);
    const endOffsetY = this.randomBetween(-250, 250);
    const durationVariance = this.randomBetween(-1, 1);
    const initialRotation = this.randomBetween(-20, 20);

    // Animation timeline
    const tl = gsap.timeline({
      onComplete: () => {
        // Navigate to /launch after animation
        window.location.href = targetUrl;
      },
    });

    // Start position: bottom-left with random offset
    gsap.set(rocket, {
      bottom: -100 + startOffsetY,
      left: -100 + startOffsetX,
      opacity: 1,
      rotation: initialRotation,
    });

    // Animate rocket flying diagonally across screen with varied end position
    tl.to(rocket, {
      duration: 3 + durationVariance,
      bottom: viewportHeight + 200 + endOffsetY,
      left: viewportWidth + 200 + endOffsetX,
      rotation: initialRotation + this.randomBetween(-5, 10),
      ease: "power2.inOut",
    });

    // Add slight wobble during flight with random intensity
    tl.to(
      rocket,
      {
        duration: 0.1,
        rotation: `+=${this.randomBetween(-5, 5)}`,
        repeat: this.randomBetween(8, 14),
        yoyo: true,
        ease: "none",
      },
      0,
    );
  }

  randomBetween(min, max) {
    return Math.random() * (max - min) + min;
  }
}
