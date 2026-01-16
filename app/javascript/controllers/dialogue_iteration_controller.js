import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "content",
    "character",
    "sticker",
    "sprite",
    "muteButton",
    "volumeOnIcon",
    "volumeOffIcon",
  ];
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
    this.squeakCount = 0;
    this.#loadMuteState();
    this.#loadSqueak();
    this.#preloadSprites();
    this.#render();
  }

  #loadMuteState() {
    const stored = localStorage.getItem("orpheus-muted");
    this.isMuted = stored === "true";
    if (typeof Howler !== "undefined") {
      Howler.mute(this.isMuted);
    }
    this.#updateMuteUI();
  }

  #updateMuteUI() {
    if (this.hasVolumeOnIconTarget && this.hasVolumeOffIconTarget) {
      this.volumeOnIconTarget.style.display = this.isMuted ? "none" : "block";
      this.volumeOffIconTarget.style.display = this.isMuted ? "block" : "none";
    }
  }

  toggleMute(event) {
    event?.preventDefault?.();
    event?.stopPropagation?.();
    this.isMuted = !this.isMuted;
    localStorage.setItem("orpheus-muted", this.isMuted);
    if (typeof Howler !== "undefined") {
      Howler.mute(this.isMuted);
    }
    this.#updateMuteUI();
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
    if (typeof this.cancelYap === "function") {
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

  squeakCharacter(event) {
    event?.stopPropagation();
    if (this.hasExploded) return;

    if (this.squeak) {
      this.squeak.play();
    } else if (this.squeakAudio) {
      this.squeakAudio.currentTime = 0;
      this.squeakAudio.play();
    }

    this.squeakCount++;
    switch (this.squeakCount) {
      case 7:
        this.#insertLine("hey, i'd rather you didn't click me...");
        break;
      case 14:
        this.#insertLine("seriously, please stop clicking me.", true);
        break;
      case 21:
        this.#insertLine("I'M TRYING TO TALK TO YOU HERE!", true);
        break;
      case 28:
        this.#insertLine("WOULD YOU PLEASE KNOCK THAT OFF!!!", true);
        break;
      case 35:
        this.#insertLine("BUDDY. PAWS OFF.", true);
        break;
      case 67:
        this.#insertLine(
          "how would you like it if i just started clicking you, huh?",
          true,
        );
        break;
      case 99:
        this.#insertLine("click me one more time. i dare you.", true);
        break;
      case 100:
        this.#explode();
        break;
    }
  }

  #explode() {
    const boom = new Audio("/boom.mp3");
    boom.play();

    this.hasExploded = true;

    if (!document.getElementById("shake-style")) {
      const style = document.createElement("style");
      style.id = "shake-style";
      style.textContent = `
        @keyframes shake {
          0%, 100% { transform: translateX(0); }
          10%, 30%, 50%, 70%, 90% { transform: translateX(-10px); }
          20%, 40%, 60%, 80% { transform: translateX(10px); }
        }
      `;
      document.head.appendChild(style);
    }

    setTimeout(() => {
      if (this.hasSpriteTarget) {
        const rect = this.spriteTarget.getBoundingClientRect();
        const scale = 2;
        const explosion = document.createElement("img");
        explosion.src = "/explode.gif";
        explosion.style.cssText = `
          position: fixed;
          top: ${rect.top - (rect.height * (scale - 1)) / 2}px;
          left: ${rect.left - (rect.width * (scale - 1)) / 2}px;
          width: ${rect.width * scale}px;
          height: ${rect.height * scale}px;
          object-fit: contain;
          z-index: 99999;
          pointer-events: none;
        `;
        document.body.appendChild(explosion);
        setTimeout(() => explosion.remove(), 2500);
      }

      const dialogueBox = this.element.querySelector(".dialogue-box");
      if (dialogueBox) {
        dialogueBox.style.animation = "shake 0.5s ease-in-out";
        setTimeout(() => {
          dialogueBox.style.animation = "";
        }, 500);
      }
    }, 1871);

    this.#insertLine("...", true);
  }

  #insertLine(text, isAngry = false) {
    this.textValue = [
      ...this.textValue.slice(0, this.index + 1),
      text,
      ...this.textValue.slice(this.index + 1),
    ];
    this.isAngry = isAngry;
    this.advance();
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

      if (typeof this.cancelYap === "function") {
        this.cancelYap();
      }

      const isAngry = this.isAngry;
      this.isAngry = false;

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
          baseRate: isAngry ? 6 : 4.5,
          rateVariance: isAngry ? 0.2 : 0.8,
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
