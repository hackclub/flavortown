import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["cookie", "counter", "clickEffect"];
  static values = {
    clicks: Number,
    postUrl: String,
    orchestraUrl: String,
    headshotUrl: String,
  };

  connect() {
    this.pendingClicks = 0;
    this.saveTimeout = null;
    this.critCount = 0;
    this.semitone = Math.pow(2, 1 / 12);
    this.audioContext = null;
    this.orchestraBuffer = null;
    if (this.hasHeadshotUrlValue) {
      this.headshotAudio = new Audio(this.headshotUrlValue);
      this.headshotAudio.volume = 0.6;
    }

    this.#loadOrchestraHit();
  }

  #loadOrchestraHit() {
    if (!this.hasOrchestraUrlValue) return;

    fetch(this.orchestraUrlValue)
      .then((response) => response.arrayBuffer())
      .then((arrayBuffer) => {
        this.audioContext = new (window.AudioContext ||
          window.webkitAudioContext)();
        return this.audioContext.decodeAudioData(arrayBuffer);
      })
      .then((buffer) => {
        this.orchestraBuffer = buffer;
      });
  }

  #playOrchestraHit(pitchMultiplier) {
    if (!this.audioContext || !this.orchestraBuffer) return;

    if (this.audioContext.state === "suspended") {
      this.audioContext.resume();
    }

    const source = this.audioContext.createBufferSource();
    const gainNode = this.audioContext.createGain();

    source.buffer = this.orchestraBuffer;
    source.playbackRate.value = pitchMultiplier;
    gainNode.gain.value = 0.5;

    source.connect(gainNode);
    gainNode.connect(this.audioContext.destination);
    source.start();
  }

  disconnect() {
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout);
      this.flushClicks();
    }
  }

  click(event) {
    event.preventDefault();

    const isCrit = Math.random() < 0.1;

    if (isCrit) {
      this.critCount++;
      const isSuperCrit = this.critCount % 20 === 0;
      const clickValue = isSuperCrit ? 10 : 5;

      this.clicksValue += clickValue;
      this.pendingClicks += clickValue;
      this.updateCounter();
      this.animateCookie();
      this.showClickEffect(event, !isSuperCrit, isSuperCrit, clickValue);

      if (isSuperCrit && this.headshotAudio) {
        this.headshotAudio.currentTime = 0;
        this.headshotAudio.play();
      } else {
        const pitch = Math.pow(this.semitone, (this.critCount - 1) % 20);
        this.#playOrchestraHit(pitch);
      }
    } else {
      this.clicksValue += 1;
      this.pendingClicks += 1;
      this.updateCounter();
      this.animateCookie();
      this.showClickEffect(event, false, false, 1);
    }

    if (this.saveTimeout) clearTimeout(this.saveTimeout);
    this.saveTimeout = setTimeout(() => this.flushClicks(), 1000);
  }

  updateCounter() {
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = this.clicksValue;
    }
  }

  animateCookie() {
    if (!this.hasCookieTarget) return;

    this.cookieTarget.classList.add("cookie-clicker__cookie--clicked");
    setTimeout(() => {
      this.cookieTarget.classList.remove("cookie-clicker__cookie--clicked");
    }, 100);
  }

  showClickEffect(event, isCrit, isSuperCrit, value) {
    const effect = document.createElement("span");
    if (isSuperCrit) {
      effect.innerHTML = `+${value} <span class="cookie-clicker__crit-text">crit!</span>`;
      effect.className =
        "cookie-clicker__effect cookie-clicker__effect--super-crit";
    } else if (isCrit) {
      effect.textContent = `+${value}`;
      effect.className = "cookie-clicker__effect cookie-clicker__effect--crit";
    } else {
      effect.textContent = `+${value}`;
      effect.className = "cookie-clicker__effect";
    }

    const randomWobble = () => Math.floor(Math.random() * 20) - 10;
    effect.style.setProperty("--wobble-1", `${randomWobble()}px`);
    effect.style.setProperty("--wobble-2", `${randomWobble()}px`);
    effect.style.setProperty("--wobble-3", `${randomWobble()}px`);
    effect.style.setProperty("--wobble-4", `${randomWobble()}px`);
    effect.style.setProperty("--wobble-5", `${randomWobble()}px`);
    effect.style.setProperty("--wobble-6", `${randomWobble()}px`);

    const dialog = this.element.closest("dialog");
    if (dialog) {
      const rect = dialog.getBoundingClientRect();
      effect.style.position = "absolute";
      effect.style.left = `${event.clientX - rect.left}px`;
      effect.style.top = `${event.clientY - rect.top}px`;
      effect.style.setProperty(
        "--float-distance",
        `${event.clientY - rect.top + 50}px`,
      );
      dialog.appendChild(effect);
    } else {
      effect.style.left = `${event.clientX}px`;
      effect.style.top = `${event.clientY}px`;
      effect.style.setProperty("--float-distance", `${event.clientY + 50}px`);
      document.body.appendChild(effect);
    }

    setTimeout(() => effect.remove(), 1500);
  }

  flushClicks() {
    if (this.pendingClicks === 0) return;

    const clicks = this.pendingClicks;
    this.pendingClicks = 0;

    const formData = new FormData();
    formData.append("clicks", clicks);

    fetch(this.postUrlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
          ?.content,
      },
      body: formData,
    });
  }
}
