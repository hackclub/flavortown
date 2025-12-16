import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["content", "character", "sticker", "sprite"];
  static values = { text: Array, voiceUrl: String, sprites: Array };

  static SPRITE_INTERVAL = 80; // in ms; time b/w sprite changes

  connect() {
    this.index = 0;
    this.typingInterval = null;
    this.spriteInterval = null;
    this.currentSpriteIndex = 0;
    this.#loadSqueak();
    this.#loadVoice();
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
    if (this.voiceAudio) this.voiceAudio.pause();
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

  #loadVoice() {
    if (!this.hasVoiceUrlValue || !this.voiceUrlValue) return;

    this.voiceAudio = new Audio(this.voiceUrlValue);
    this.voiceAudio.volume = 0.5;
  }

  #stopTyping() {
    if (this.typingInterval) {
      clearInterval(this.typingInterval);
      this.typingInterval = null;
    }
    this.#stopSpriteAnimation();
  }

  next(event) {
    event?.preventDefault?.();
    event?.stopPropagation?.();

    if (this.typingInterval) {
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

    // pop up sticker on 3rd line
    if (nextIndex === 2 && this.hasStickerTarget) {
      this.stickerTarget.classList.remove("dialogue-box__sticker--hidden");
    }
  }

  close() {
    this.#stopTyping();
    if (this.voiceAudio) this.voiceAudio.pause();
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

  #completeTyping() {
    this.#stopTyping();
    if (this.voiceAudio) this.voiceAudio.pause();
    if (!this.hasContentTarget) return;
    const line = this.textValue?.[this.index] ?? "";
    this.contentTarget.textContent = line;
  }

  #render() {
    if (!this.hasContentTarget) return;

    const line = this.textValue?.[this.index] ?? "";
    this.contentTarget.textContent = "";

    this.#stopTyping();
    if (this.voiceAudio) this.voiceAudio.pause();

    if (!line) return;

    this.voiceAudio.currentTime = 0;
    this.voiceAudio.play();
    this.#startSpriteAnimation();
    let charIndex = 0;

    this.typingInterval = setInterval(() => {
      if (charIndex < line.length) {
        this.contentTarget.textContent += line[charIndex];
        charIndex++;
      } else {
        this.#stopTyping();
        if (this.voiceAudio) this.voiceAudio.pause();
      }
    }, 30); // 30ms
  }
}
