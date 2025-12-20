import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    showHackatimeTutorial: Boolean,
    showSlackTutorial: Boolean,
  };

  connect() {
    // Check if welcome overlay exists
    const welcomeOverlay = document.querySelector(
      '[data-controller*="welcome-overlay"]',
    );

    if (welcomeOverlay) {
      // Listen for the welcome overlay dismissal event
      this.boundShowDialogue = this.showWelcomeDialogue.bind(this);
      window.addEventListener(
        "welcome-overlay:dismissed",
        this.boundShowDialogue,
      );
    } else {
      // If no overlay exists, show dialogue immediately
      this.showWelcomeDialogue();
    }

    // Listen for dialogue completion events
    this.boundOnDialogueComplete = this.onDialogueComplete.bind(this);
    window.addEventListener("dialogue:complete", this.boundOnDialogueComplete);
  }

  disconnect() {
    if (this.boundShowDialogue) {
      window.removeEventListener(
        "welcome-overlay:dismissed",
        this.boundShowDialogue,
      );
    }
    if (this.boundOnDialogueComplete) {
      window.removeEventListener(
        "dialogue:complete",
        this.boundOnDialogueComplete,
      );
    }
  }

  showWelcomeDialogue() {
    const dialogueWrapper = this.element.querySelector(
      ".dialogue-box-wrapper--welcome",
    );

    if (dialogueWrapper && !dialogueWrapper.hasAttribute("data-controller")) {
      // Show the container first
      this.element.style.display = "";

      // Add the dialogue-iteration controller attribute
      dialogueWrapper.setAttribute("data-controller", "dialogue-iteration");
    } else {
      // Just show the container if controller is already connected
      this.element.style.display = "";
    }
  }

  onDialogueComplete(event) {
    const dialogueType = event.detail?.type;

    if (dialogueType === "welcome") {
      // After welcome dialogue, show hackatime tutorial if needed
      if (
        this.hasShowHackatimeTutorialValue &&
        this.showHackatimeTutorialValue
      ) {
        this.showHackatimeDialogue();
      } else if (
        this.hasShowSlackTutorialValue &&
        this.showSlackTutorialValue
      ) {
        // If no hackatime tutorial, show slack if needed
        this.showSlackDialogue();
      }
    } else if (dialogueType === "hackatime") {
      // After hackatime dialogue, show slack tutorial if needed
      if (this.hasShowSlackTutorialValue && this.showSlackTutorialValue) {
        this.showSlackDialogue();
      }
    }
  }

  showHackatimeDialogue() {
    const dialogueWrapper = this.element.querySelector(
      ".dialogue-box-wrapper--hackatime",
    );

    if (dialogueWrapper && !dialogueWrapper.hasAttribute("data-controller")) {
      // Show the container and the wrapper
      this.element.style.display = "";
      dialogueWrapper.style.display = "";
      dialogueWrapper.setAttribute("data-controller", "dialogue-iteration");
    } else if (dialogueWrapper) {
      // Just show if controller is already connected
      this.element.style.display = "";
      dialogueWrapper.style.display = "";
    }
  }

  showSlackDialogue() {
    const dialogueWrapper = this.element.querySelector(
      ".dialogue-box-wrapper--slack",
    );

    if (dialogueWrapper && !dialogueWrapper.hasAttribute("data-controller")) {
      // Show the container and the wrapper
      this.element.style.display = "";
      dialogueWrapper.style.display = "";
      dialogueWrapper.setAttribute("data-controller", "dialogue-iteration");
    } else if (dialogueWrapper) {
      // Just show if controller is already connected
      this.element.style.display = "";
      dialogueWrapper.style.display = "";
    }
  }
}
