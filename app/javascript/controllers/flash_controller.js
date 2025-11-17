import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    timeout: { type: Number, default: 5000 },
  };

  connect() {
    this.startTimer();
    this.mouseEnterHandler = () => this.clearTimer();
    this.mouseLeaveHandler = () => this.startTimer();
    this.element.addEventListener("mouseenter", this.mouseEnterHandler);
    this.element.addEventListener("mouseleave", this.mouseLeaveHandler);
  }

  disconnect() {
    this.clearTimer();
    if (this.mouseEnterHandler)
      this.element.removeEventListener("mouseenter", this.mouseEnterHandler);
    if (this.mouseLeaveHandler)
      this.element.removeEventListener("mouseleave", this.mouseLeaveHandler);
  }

  close(event) {
    if (event) event.preventDefault();
    this.hideAndRemove();
  }

  startTimer() {
    this.clearTimer();
    if (this.timeoutValue > 0) {
      this.timer = setTimeout(() => this.hideAndRemove(), this.timeoutValue);
    }
  }

  clearTimer() {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
  }

  hideAndRemove() {
    this.clearTimer();
    this.element.classList.add("alert--hiding");
    const onEnd = () => {
      this.element.removeEventListener("transitionend", onEnd);
      this.element.remove();
    };
    this.element.addEventListener("transitionend", onEnd);
    setTimeout(() => {
      if (this.element && this.element.parentNode) this.element.remove();
    }, 300);
  }
}
