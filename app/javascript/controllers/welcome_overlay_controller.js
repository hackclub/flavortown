import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["star", "banner", "hint"];
  static values = { audioUrl: String };

  connect() {
    this.audio = null;
    this.audioStarted = false;
    this.canDismiss = false;

    document.body.style.overflow = "hidden";

    // Start animations after a brief delay
    requestAnimationFrame(() => {
      this.#startAnimations();
      this.#playAudio();
    });

    setTimeout(() => {
      this.canDismiss = true;
      if (this.hasHintTarget) {
        this.hintTarget.classList.add("welcome-overlay__hint--visible");
      }
    }, 3000);
  }

  disconnect() {
    document.body.style.overflow = "";
    this.#stopAudio();
  }

  dismiss() {
    if (!this.canDismiss) return;

    // Try to play audio on first click if autoplay was blocked
    if (!this.audioStarted) {
      this.#playAudio();
      this.audioStarted = true;
      return; // Don't dismiss on first click if audio wasn't playing
    }

    this.#stopAudio();
    this.element.classList.add("welcome-overlay--dismissing");

    // Dispatch event to show dialogue box after overlay is dismissed
    setTimeout(() => {
      this.element.remove();
      window.dispatchEvent(new CustomEvent("welcome-overlay:dismissed"));
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
      }, 3000);
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
