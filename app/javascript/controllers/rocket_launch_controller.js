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

    // Animation timeline
    const tl = gsap.timeline({
      onComplete: () => {
        // Navigate to /launch after animation
        window.location.href = targetUrl;
      },
    });

    // Start position: bottom-left, just off screen
    gsap.set(rocket, {
      bottom: -100,
      left: -100,
      opacity: 1,
      rotation: 0,
    });

    // Animate rocket flying diagonally across screen
    tl.to(rocket, {
      duration: 3,
      bottom: viewportHeight + 200,
      left: viewportWidth + 200,
      rotation: 5, // Slight wobble
      ease: "power2.inOut",
    });

    // Add slight wobble during flight
    tl.to(
      rocket,
      {
        duration: 0.1,
        rotation: -3,
        repeat: 10,
        yoyo: true,
        ease: "none",
      },
      0,
    ); // Start at same time as main animation
  }
}
