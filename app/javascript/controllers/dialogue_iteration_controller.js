import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["content", "character"];
  static values = { text: Array };

  connect() {
    this.index = 0;
    this.#render();
    this.#loadSqueak();
  }

  #loadSqueak() {
    if (typeof Howl !== "undefined") {
      this.squeak = new Howl({
        src: [
          "https://hc-cdn.hel1.your-objectstorage.com/s/v3/ff2d5691f663fc471761f4407856a26291926baf_squeak_audio.mp4",
        ],
      });
    } else {
      this.squeakAudio = new Audio(
        "https://hc-cdn.hel1.your-objectstorage.com/s/v3/ff2d5691f663fc471761f4407856a26291926baf_squeak_audio.mp4",
      );
    }
  }

  next(event) {
    event?.preventDefault?.();
    event?.stopPropagation?.();

    const lines = Array.isArray(this.textValue) ? this.textValue : [];
    if (lines.length === 0) return this.close();

    const nextIndex = this.index + 1;
    if (nextIndex >= lines.length) return this.close();

    this.index = nextIndex;
    this.#render();
  }

  close() {
    const backdrop = this.element.previousElementSibling;
    if (backdrop?.classList?.contains("dialogue-box-backdrop")) {
      backdrop.remove();
    }
    this.element.remove();
  }

  squeakCharacter() {
    if (this.squeak) {
      this.squeak.play();
    } else if (this.squeakAudio) {
      this.squeakAudio.currentTime = 0;
      this.squeakAudio.play();
    }
  }

  #render() {
    if (!this.hasContentTarget) return;
    const line = this.textValue?.[this.index] ?? "";
    this.contentTarget.textContent = line;
  }
}
