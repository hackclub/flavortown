import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { audioUrls: Array, defaultIndex: { type: Number, default: 0 } };

  connect() {
    this.currentIndex = this.defaultIndexValue;
    this.isPlaying = false;
    this.volume = 0.5;
    this.audioContext = null;
    this.gainNode = null;
    this.sourceNode = null;
    this.buffer = null;
  }

  async togglePlay() {
    if (this.isPlaying) {
      this.#pause();
    } else {
      await this.#play();
    }
    this.#toggleIcons();
  }

  changeVolume(event) {
    this.volume = parseFloat(event.target.value);
    if (this.gainNode) this.gainNode.gain.value = this.volume;
  }

  async prevTrack() {
    this.currentIndex = (this.currentIndex - 1 + this.audioUrlsValue.length) % this.audioUrlsValue.length;
    await this.#switchTrack();
  }

  async nextTrack() {
    this.currentIndex = (this.currentIndex + 1) % this.audioUrlsValue.length;
    await this.#switchTrack();
  }

  disconnect() {
    this.#pause();
    this.audioContext?.close();
    this.audioContext = null;
  }

  async #play() {
    if (!this.audioContext) {
      this.audioContext = new AudioContext();
      this.gainNode = this.audioContext.createGain();
      this.gainNode.gain.value = this.volume;
      this.gainNode.connect(this.audioContext.destination);
    }

    await this.audioContext.resume();

    if (!this.buffer) await this.#loadBuffer();

    this.sourceNode = this.audioContext.createBufferSource();
    this.sourceNode.buffer = this.buffer;
    this.sourceNode.loop = true;
    this.sourceNode.connect(this.gainNode);
    this.sourceNode.start(0);

    this.isPlaying = true;
  }

  #pause() {
    if (this.sourceNode) {
      this.sourceNode.onended = null;
      this.sourceNode.stop();
      this.sourceNode = null;
    }
    this.isPlaying = false;
  }

  async #switchTrack() {
    const wasPlaying = this.isPlaying;
    this.#pause();
    this.buffer = null;
    if (wasPlaying) {
      await this.#play();
      this.#toggleIcons();
    }
  }

  async #loadBuffer() {
    const response = await fetch(this.audioUrlsValue[this.currentIndex]);
    const arrayBuffer = await response.arrayBuffer();
    this.buffer = await this.audioContext.decodeAudioData(arrayBuffer);
  }

  #toggleIcons() {
    this.element.querySelectorAll(".music-player__icon--play").forEach(el => el.hidden = this.isPlaying);
    this.element.querySelectorAll(".music-player__icon--pause").forEach(el => el.hidden = !this.isPlaying);
  }
}
