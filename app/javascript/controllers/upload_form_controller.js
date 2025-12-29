import { Controller } from "@hotwired/stimulus";

// Disables form submission while Active Storage direct uploads are in progress
export default class extends Controller {
  static targets = ["submit"];

  #uploadsInProgress = 0;
  #originalText = null;

  connect() {
    // Listen for direct upload events on the form
    this.element.addEventListener(
      "direct-upload:start",
      this.#handleUploadStart,
    );
    this.element.addEventListener("direct-upload:end", this.#handleUploadEnd);
    this.element.addEventListener(
      "direct-upload:error",
      this.#handleUploadEnd,
    );

    // Also prevent form submission while uploads are in progress
    this.element.addEventListener("submit", this.#handleSubmit);
  }

  disconnect() {
    this.element.removeEventListener(
      "direct-upload:start",
      this.#handleUploadStart,
    );
    this.element.removeEventListener(
      "direct-upload:end",
      this.#handleUploadEnd,
    );
    this.element.removeEventListener(
      "direct-upload:error",
      this.#handleUploadEnd,
    );
    this.element.removeEventListener("submit", this.#handleSubmit);
  }

  #handleUploadStart = () => {
    this.#uploadsInProgress++;
    this.#disableSubmit();
  };

  #handleUploadEnd = () => {
    this.#uploadsInProgress = Math.max(0, this.#uploadsInProgress - 1);
    if (this.#uploadsInProgress === 0) {
      this.#enableSubmit();
    }
  };

  #handleSubmit = (event) => {
    if (this.#uploadsInProgress > 0) {
      event.preventDefault();
      return false;
    }
  };

  #disableSubmit() {
    if (!this.hasSubmitTarget) return;

    if (this.#originalText === null) {
      this.#originalText = this.submitTarget.textContent;
    }
    this.submitTarget.disabled = true;
    this.submitTarget.textContent = "Uploading...";
  }

  #enableSubmit() {
    if (!this.hasSubmitTarget) return;

    this.submitTarget.disabled = false;
    if (this.#originalText !== null) {
      this.submitTarget.textContent = this.#originalText;
    }
  }
}
