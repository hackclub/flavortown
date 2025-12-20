import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["body"];
  static values = { imageUrl: String };

  connect() {
    if (this.hasBodyTarget) {
      this.bodyTarget.value =
        "I'm working on my first project! This is so exciting. I can't wait to share more updates as I build.";
    }

    setTimeout(() => {
      this.prefillImage();
    }, 100);
  }

  async prefillImage() {
    const fileInput = this.element.querySelector(
      'input[type="file"][name*="devlog_attachment"]',
    );
    if (!fileInput) return;

    if (!this.hasImageUrlValue) {
      console.warn("Image URL not provided");
      return;
    }

    try {
      // Fetch the image from assets
      const response = await fetch(this.imageUrlValue);
      if (!response.ok) {
        console.warn("Could not load free sticker image");
        return;
      }

      const blob = await response.blob();
      const file = new File([blob], "free_sticker.png", { type: blob.type });

      // Create a DataTransfer object to add the file to the input
      const dataTransfer = new DataTransfer();
      dataTransfer.items.add(file);

      // Set the files on the input
      fileInput.files = dataTransfer.files;

      // Trigger change event to notify the file-upload controller
      fileInput.dispatchEvent(new Event("change", { bubbles: true }));
    } catch (error) {
      console.warn("Error prefilling image:", error);
    }
  }
}
