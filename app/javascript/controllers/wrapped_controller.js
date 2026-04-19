import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["slide", "segment"];
  static values = {
    current: { type: Number, default: 0 },
    interval: { type: Number, default: 8000 },
  };

  connect() {
    this.showSlide(0);
    this.startTimer();
  }

  disconnect() {
    this.stopTimer();
  }

  click(event) {
    const rect = this.element.getBoundingClientRect();
    const x = event.clientX - rect.left;
    if (x < rect.width / 4) {
      this.back();
    } else {
      this.advance();
    }
  }

  advance() {
    const next = this.currentValue + 1;
    if (next < this.slideTargets.length) {
      this.showSlide(next);
      this.resetTimer();
    }
  }

  back() {
    const prev = this.currentValue - 1;
    if (prev >= 0) {
      this.showSlide(prev);
      this.resetTimer();
    }
  }

  showSlide(index) {
    this.currentValue = index;

    this.slideTargets.forEach((slide, i) => {
      slide.classList.remove("active", "prev");
      if (i === index) slide.classList.add("active");
      if (i === index - 1) slide.classList.add("prev");
    });

    this.segmentTargets.forEach((seg, i) => {
      seg.classList.remove("filled", "current", "empty");
      if (i < index) seg.classList.add("filled");
      else if (i === index) seg.classList.add("current");
      else seg.classList.add("empty");
    });

    // Restart the fill animation on the current segment
    const currentSeg = this.segmentTargets[index];
    if (currentSeg) {
      currentSeg.style.setProperty("--segment-duration", `${this.intervalValue}ms`);
    }
  }

  startTimer() {
    this.timer = setInterval(() => this.advance(), this.intervalValue);
  }

  stopTimer() {
    if (this.timer) clearInterval(this.timer);
  }

  resetTimer() {
    this.stopTimer();
    this.startTimer();
  }
}
