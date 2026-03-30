import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["days", "hours", "minutes", "seconds"];
  static values = { target: String };

  connect() {
    this.endTime = new Date(this.targetValue).getTime();
    this.updateTimer();
    this.timer = setInterval(() => {
      this.updateTimer();
    }, 1000);
  }

  disconnect() {
    clearInterval(this.timer);
  }

  updateTimer() {
    const now = new Date().getTime();
    const distance = this.endTime - now;

    if (distance <= 0) {
      this.daysTarget.textContent = "00";
      this.hoursTarget.textContent = "00";
      this.minutesTarget.textContent = "00";
      this.secondsTarget.textContent = "00";
      clearInterval(this.timer);
      return;
    }

    const days = Math.floor(distance / (1000 * 60 * 60 * 24));
    const hours = Math.floor(
      (distance % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60),
    );
    const minutes = Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60));
    const seconds = Math.floor((distance % (1000 * 60)) / 1000);

    this.daysTarget.textContent = days.toString().padStart(2, "0");
    this.hoursTarget.textContent = hours.toString().padStart(2, "0");
    this.minutesTarget.textContent = minutes.toString().padStart(2, "0");
    this.secondsTarget.textContent = seconds.toString().padStart(2, "0");
  }
}
