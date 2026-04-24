import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["display"];
  static values = { date: String };

  connect() {
    this.targetDate = new Date(this.dateValue).getTime();
    this.updateTimer();
    this.timer = setInterval(() => this.updateTimer(), 1000);
  }

  disconnect() {
    clearInterval(this.timer);
  }

  updateTimer() {
    const now = new Date().getTime();
    const distance = this.targetDate - now;

    if (distance < 0) {
      this.displayTarget.textContent = "Ended";
      clearInterval(this.timer);
      return;
    }

    const days = Math.floor(distance / (1000 * 60 * 60 * 24));
    const hours = Math.floor(
      (distance % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60),
    );
    const minutes = Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60));
    const seconds = Math.floor((distance % (1000 * 60)) / 1000);

    this.displayTarget.textContent = `${days}d ${hours}h ${minutes}m ${seconds}s`;
  }
}
