import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["star", "banner", "hint"];
  static values = { audioUrl: String };

  connect() {
    this.audio = null;
    this.audioStarted = false;
    document.body.style.overflow = "hidden";

    // Start animations after a brief delay
    requestAnimationFrame(() => {
      this.#startAnimations();
      this.#playAudio();
    });
  }

  disconnect() {
    document.body.style.overflow = "";
    this.#stopAudio();
  }

  dismiss() {
    // Try to play audio on first click if autoplay was blocked
    if (!this.audioStarted) {
      this.#playAudio();
      this.audioStarted = true;
      return; // Don't dismiss on first click if audio wasn't playing
    }

    this.#stopAudio();
    this.element.classList.add("welcome-overlay--dismissing");

    // Wait for dismiss animation to complete
    setTimeout(() => {
      this.element.remove();
    }, 400);
  }

  #startAnimations() {
    // Animate banner
    if (this.hasBannerTarget) {
      this.bannerTarget.classList.add("welcome-overlay__banner--animate");
    }

    // Animate stars with staggered delay
    this.starTargets.forEach((star, index) => {
      setTimeout(
        () => {
          star.classList.add("welcome-overlay__star--animate");
        },
        200 + index * 100,
      );
    });

    // Show hint after animations
    if (this.hasHintTarget) {
      setTimeout(() => {
        this.hintTarget.classList.add("welcome-overlay__hint--visible");
      }, 1000);
    }
  }

  #playAudio() {
    if (!this.hasAudioUrlValue || !this.audioUrlValue) return;
    if (this.audioStarted) return;

    // Use Howl if available, otherwise fallback to Audio API
    if (typeof Howl !== "undefined") {
      this.audio = new Howl({
        src: [this.audioUrlValue],
        volume: 0.6,
        onplay: () => {
          this.audioStarted = true;
        },
        onend: () => {
          // Audio finished
        },
      });
      this.audio.play();
    } else {
      this.audio = new Audio(this.audioUrlValue);
      this.audio.volume = 0.6;
      this.audio
        .play()
        .then(() => {
          this.audioStarted = true;
        })
        .catch(() => {
          // Audio autoplay blocked, will try on user click
        });
    }
  }

  #stopAudio() {
    if (!this.audio) return;

    if (typeof Howl !== "undefined" && this.audio instanceof Howl) {
      this.audio.stop();
    } else if (this.audio instanceof Audio) {
      this.audio.pause();
      this.audio.currentTime = 0;
    }
  }
}
