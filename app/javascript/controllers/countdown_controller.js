import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["display", "localTime"];
  static values = { date: String };

  connect() {
    this.target = new Date(this.dateValue).getTime();
    this.renderLocalTime();
    this.updateTimer();
    this.timer = setInterval(() => this.updateTimer(), 1000);
  }

  disconnect() {
    clearInterval(this.timer);
  }

  renderLocalTime() {
    if (!this.hasLocalTimeTarget || Number.isNaN(this.target)) return;

    const fmt = new Intl.DateTimeFormat("en-US", {
      weekday: "long", month: "long", day: "numeric",
      hour: "numeric", minute: "2-digit", timeZoneName: "short",
    });
    const d = new Date(this.target);
    const p = Object.fromEntries(fmt.formatToParts(d).map((x) => [x.type, x.value]));

    if (["weekday", "month", "day", "hour", "minute", "timeZoneName"].some((k) => !p[k])) {
      this.localTimeTarget.textContent = fmt.format(d);
      return;
    }

    const suffix = p.dayPeriod ? ` ${p.dayPeriod}` : "";
    this.localTimeTarget.textContent =
      `${p.weekday}, ${p.month} ${p.day} at ${p.hour}:${p.minute}${suffix} ${p.timeZoneName}`;
  }

  updateTimer() {
    const dist = this.target - Date.now();

    if (dist < 0) {
      this.displayTarget.textContent = "Ended";
      clearInterval(this.timer);
      return;
    }

    const d = Math.floor(dist / 86400000);
    const h = Math.floor((dist % 86400000) / 3600000);
    const m = Math.floor((dist % 3600000) / 60000);
    const s = Math.floor((dist % 60000) / 1000);

    this.displayTarget.textContent = `${d}d ${h}h ${m}m ${s}s`;
  }
}
