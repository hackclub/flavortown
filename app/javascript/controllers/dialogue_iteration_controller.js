import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["content", "character", "sticker", "sprite"];
  static values = {
    text: Array,
    sprites: Array,
    redirectUrl: String,
    stickerLineIndex: Number,
  };

  static SPRITE_INTERVAL = 80; // in ms; time b/w sprite changes

  connect() {
    this.index = 0;
    this.isTyping = false;
    this.spriteInterval = null;
    this.currentSpriteIndex = 0;
    this.yapGeneration = 0;
    this.#loadSqueak();
    this.#preloadSprites();
    this.#render();
  }

  #preloadSprites() {
    if (!this.hasSpritesValue) return;

    this.spriteImages = this.spritesValue.map((url) => {
      const img = new Image();
      img.src = url;
      return img;
    });
  }

  disconnect() {
    this.#stopTyping();
    this.#stopSpriteAnimation();
  }

  #startSpriteAnimation() {
    if (this.spriteInterval || !this.hasSpriteTarget || !this.hasSpritesValue)
      return;

    this.spriteInterval = setInterval(() => {
      this.currentSpriteIndex =
        (this.currentSpriteIndex + 1) % this.spritesValue.length;
      this.spriteTarget.src = this.spritesValue[this.currentSpriteIndex];
    }, this.constructor.SPRITE_INTERVAL);
  }

  #stopSpriteAnimation() {
    if (this.spriteInterval) {
      clearInterval(this.spriteInterval);
      this.spriteInterval = null;
    }

    if (this.hasSpriteTarget && this.hasSpritesValue) {
      this.currentSpriteIndex = 7; // 8.png
      this.spriteTarget.src = this.spritesValue[7];
    }
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

  #stopTyping() {
    this.isTyping = false;
    if (this.cancelYap) {
      this.cancelYap();
      this.cancelYap = null;
    }
    this.#stopSpriteAnimation();
  }

  next(event) {
    event?.preventDefault?.();
    event?.stopPropagation?.();

    if (this.isTyping) {
      this.#completeTyping();
      return;
    }

    this.advance();
  }

  advance() {
    const lines = Array.isArray(this.textValue) ? this.textValue : [];
    if (lines.length === 0) return this.close();

    const nextIndex = this.index + 1;
    if (nextIndex >= lines.length) return this.close();

    this.index = nextIndex;
    this.#render();
    if (this.hasStickerTarget) {
      const stickerLine = this.hasStickerLineIndexValue
        ? this.stickerLineIndexValue
        : 2;
      if (nextIndex === stickerLine) {
        this.stickerTarget.classList.remove("dialogue-box__sticker--hidden");
      } else {
        this.stickerTarget.classList.add("dialogue-box__sticker--hidden");
      }
    }
  }

  close() {
    this.#stopTyping();

    const dialogueType = this.element.dataset.dialogueType;

    this.element.remove();

    if (dialogueType) {
      window.dispatchEvent(
        new CustomEvent("dialogue:complete", {
          detail: { type: dialogueType },
        }),
      );
    }

    if (this.hasRedirectUrlValue && this.redirectUrlValue) {
      if (this.redirectUrlValue.startsWith(window.location.origin)) {
        Turbo.visit(this.redirectUrlValue);
      } else {
        window.location.href = this.redirectUrlValue;
      }
    }
  }

  squeakCharacter() {
    if (this.squeak) {
      this.squeak.play();
    } else if (this.squeakAudio) {
      this.squeakAudio.currentTime = 0;
      this.squeakAudio.play();
    }
  }

  #completeTyping() {
    this.#stopTyping();
    if (!this.hasContentTarget) return;
    const line = this.textValue?.[this.index] ?? "";
    this.contentTarget.textContent = line;
  }

  #render() {
    if (!this.hasContentTarget) return;

    const line = this.textValue?.[this.index] ?? "";
    this.contentTarget.textContent = "";

    this.#stopTyping();

    if (!line) return;

    if (this.hasStickerTarget) {
      const stickerLine = this.hasStickerLineIndexValue
        ? this.stickerLineIndexValue
        : 2;
      if (this.index === stickerLine) {
        this.stickerTarget.classList.remove("dialogue-box__sticker--hidden");
      } else {
        this.stickerTarget.classList.add("dialogue-box__sticker--hidden");
      }
    }

    this.#startSpriteAnimation();
    this.isTyping = true;

    if (typeof yap === "function") {
      this.yapGeneration++;
      const currentGeneration = this.yapGeneration;

      if (this.cancelYap) {
        this.cancelYap();
      }

      const yapPromise = new Promise((resolve) => {
        this.cancelYap = yap(line, {
          letterCallback: ({ letter }) => {
            if (this.yapGeneration !== currentGeneration) return;
            if (!this.isTyping) return;
            this.contentTarget.textContent += letter;
            this.#scrollToBottom();
            resolve("yap");
          },
          endCallback: () => {
            if (this.yapGeneration !== currentGeneration) return;
            this.#stopTyping();
          },
          baseRate: 4.5,
          rateVariance: 0.8,
        });
      });

      const timeoutPromise = new Promise((resolve) =>
        setTimeout(() => resolve("timeout"), 100),
      );

      Promise.any([yapPromise, timeoutPromise]).then((winner) => {
        if (this.yapGeneration !== currentGeneration) return;
        if (winner === "timeout") {
          this.#completeTyping();
        }
      });
    } else {
      this.contentTarget.textContent = line;
      this.#stopTyping();
    }
  }

  #scrollToBottom() {
    const container = this.contentTarget.closest(".dialogue-box__text-content");
    if (container) {
      container.scrollTop = container.scrollHeight;
    }
  }
}
