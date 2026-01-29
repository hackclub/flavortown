import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    url: String,
    loaded: { type: Boolean, default: false },
  };

  static targets = ["popover"];

  connect() {
    this.hideTimeout = null;
  }

  disconnect() {
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout);
    }
  }

  show() {
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout);
      this.hideTimeout = null;
    }

    if (!this.loadedValue && this.urlValue) {
      this.fetchStats();
    }

    this.popoverTarget.classList.add("stats-hover-popover--visible");
  }

  hide() {
    this.hideTimeout = setTimeout(() => {
      this.popoverTarget.classList.remove("stats-hover-popover--visible");
    }, 150);
  }

  popoverEnter() {
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout);
      this.hideTimeout = null;
    }
  }

  popoverLeave() {
    this.hide();
  }

  async fetchStats() {
    this.popoverTarget.innerHTML =
      '<div class="stats-hover-popover__loading">Loading...</div>';
    this.loadedValue = true;

    try {
      const response = await fetch(this.urlValue, {
        headers: {
          Accept: "application/json",
          "X-Requested-With": "XMLHttpRequest",
        },
      });

      if (!response.ok) {
        throw new Error("Failed to fetch stats");
      }

      const data = await response.json();
      this.renderStats(data);
    } catch (error) {
      this.popoverTarget.innerHTML =
        '<div class="stats-hover-popover__error">Failed to load stats</div>';
    }
  }

  renderStats(data) {
    const items = Object.entries(data)
      .map(([key, value]) => {
        const label = this.formatLabel(key);
        const formattedValue = this.formatValue(key, value);
        return `<div class="stats-hover-popover__item"><span class="stats-hover-popover__label">${label}:</span> <span class="stats-hover-popover__value">${formattedValue}</span></div>`;
      })
      .join("");

    this.popoverTarget.innerHTML = items;
  }

  formatLabel(key) {
    return key.replace(/_/g, " ").replace(/\b\w/g, (l) => l.toUpperCase());
  }

  formatValue(key, value) {
    if (value === null || value === undefined) {
      return "N/A";
    }

    if (key === "created_at" || key.includes("_at")) {
      return new Date(value).toLocaleDateString();
    }

    if (typeof value === "boolean") {
      return value ? "Yes" : "No";
    }

    return value;
  }
}
