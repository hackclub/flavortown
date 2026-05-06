import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["display", "localTime"];
  static values = { date: String };

  connect() {
    this.targetDate = new Date(this.dateValue).getTime();
    this.renderLocalTime();
    this.updateTimer();
    this.timer = setInterval(() => this.updateTimer(), 1000);
  }

  disconnect() {
    clearInterval(this.timer);
  }

  renderLocalTime() {
    if (!this.hasLocalTimeTarget || Number.isNaN(this.targetDate)) return;

    const formatter = new Intl.DateTimeFormat(undefined, {
      weekday: "long",
      month: "long",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
      timeZoneName: "short",
    });

    this.localTimeTarget.textContent = formatter.format(
      new Date(this.targetDate),
    );
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
