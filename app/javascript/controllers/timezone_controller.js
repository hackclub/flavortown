import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    if (!this.hasTimezoneCookie()) {
      this.setTimezoneCookie();
    }
  }

  hasTimezoneCookie() {
    return document.cookie
      .split(";")
      .some((c) => c.trim().startsWith("timezone="));
  }

  setTimezoneCookie() {
    const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    if (timezone) {
      document.cookie = `timezone=${encodeURIComponent(timezone)};path=/;max-age=31536000;SameSite=Lax`;
    }
  }
}
