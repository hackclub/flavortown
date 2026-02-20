import { Controller } from "@hotwired/stimulus";

// Disables form submission while Active Storage direct uploads are in progress
export default class extends Controller {
  static targets = ["submit", "removeCheckbox"];

  #uploadsInProgress = 0;
  #originalText = null;

  connect() {
    // Listen for direct upload events on the form
    this.element.addEventListener(
      "direct-upload:start",
      this.#handleUploadStart,
    );
    this.element.addEventListener("direct-upload:end", this.#handleUploadEnd);
    this.element.addEventListener("direct-upload:error", this.#handleUploadEnd);

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

    // prevent user from removing all attachments without adding new ones
    if (this.#removingAllAttachments()) {
      event.preventDefault();
      alert('You cannot remove all attachments without adding new ones. Please add at least one attachment or keep at least one existing attachment.');
      
      return false;
    }
  };

  // check if the user is trying to remove all existing attachments without adding new ones
  #removingAllAttachments() {
    if (!this.hasRemoveCheckboxTarget) return false;

    const totalAttachments = this.removeCheckboxTargets.length;
    const remcount = this.removeCheckboxTargets.filter((cb) => cb.checked).length;
    if (remcount === 0) return false;

    const fileInput = this.element.querySelector('input[type="file"]');
    return (totalAttachments - remcount) + (fileInput ? fileInput.files.length : 0) < 1;
  }

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
