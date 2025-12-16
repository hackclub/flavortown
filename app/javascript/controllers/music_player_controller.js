import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { audioUrl: String };

  connect() {
    this.audio = new Audio(this.audioUrlValue);
    this.audio.loop = true;
    this.audio.volume = 0.5;

    this.isPlaying = false;
  }

  togglePlay() {
    if (this.isPlaying) {
      this.audio.pause();
      this.isPlaying = false;
    } else {
      this.audio.play();
      this.isPlaying = true;
    }
    this.#toggleIcons();
  }

  changeVolume(event) {
    this.audio.volume = event.target.value;
  }

  #toggleIcons() {
    const playIcon = this.element.querySelector(".music-player__icon--play");
    const pauseIcon = this.element.querySelector(".music-player__icon--pause");

    if (this.isPlaying) {
      playIcon.hidden = true;
      pauseIcon.hidden = false;
    } else {
      playIcon.hidden = false;
      pauseIcon.hidden = true;
    }
  }
}