import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    // Check if welcome overlay exists
    const welcomeOverlay = document.querySelector(
      '[data-controller*="welcome-overlay"]',
    );

    if (welcomeOverlay) {
      // Listen for the welcome overlay dismissal event
      this.boundShowDialogue = this.showDialogue.bind(this);
      window.addEventListener(
        "welcome-overlay:dismissed",
        this.boundShowDialogue,
      );
    } else {
      // If no overlay exists, show dialogue immediately
      this.showDialogue();
    }
  }

  disconnect() {
    if (this.boundShowDialogue) {
      window.removeEventListener(
        "welcome-overlay:dismissed",
        this.boundShowDialogue,
      );
    }
  }

  showDialogue() {
    // Find the dialogue box wrapper inside the container
    const dialogueWrapper = this.element.querySelector(".dialogue-box-wrapper");

    if (dialogueWrapper && !dialogueWrapper.hasAttribute("data-controller")) {
      // Show the container first
      this.element.style.display = "";

      // Add the dialogue-iteration controller attribute
      // Stimulus will automatically detect and connect the controller
      dialogueWrapper.setAttribute("data-controller", "dialogue-iteration");
    } else {
      // Just show the container if controller is already connected
      this.element.style.display = "";
    }
  }
}
