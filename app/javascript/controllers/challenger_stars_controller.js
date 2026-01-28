import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.boundHandleScroll = this.handleScroll.bind(this);
    
    // Wait for stars SVG to be created
    this.checkForStars();
  }

  checkForStars() {
    this.starsContainer = document.querySelector(".launch-stars-svg");
    
    if (this.starsContainer) {
      window.addEventListener("scroll", this.boundHandleScroll, { passive: true });
      this.handleScroll();
    } else {
      // Keep checking until stars appear
      setTimeout(() => this.checkForStars(), 100);
    }
  }

  handleScroll() {
    const starsContainer = document.querySelector(".launch-stars-svg");
    if (!starsContainer) return;

    const heroHeight = this.element.offsetHeight;
    const scrollY = window.scrollY;
    
    // Fade out as user scrolls
    const fadeStart = heroHeight * 0.2;
    const fadeEnd = heroHeight * 0.7;
    
    let opacity = 1;
    if (scrollY > fadeStart) {
      opacity = Math.max(0, 1 - (scrollY - fadeStart) / (fadeEnd - fadeStart));
    }
    
    starsContainer.style.opacity = String(opacity);
  }

  disconnect() {
    window.removeEventListener("scroll", this.boundHandleScroll);
    
    const starsContainer = document.querySelector(".launch-stars-svg");
    if (starsContainer) {
      starsContainer.style.opacity = "1";
    }
  }
}
