import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["warning"];
  static values = {
    itemType: String,
    usOriginMessage: String,
    unknownOriginMessage: String,
  };

  connect() {
    this.updateWarning(null);
  }

  addressChanged(event) {
    const country = event.detail?.country || null;
    this.updateWarning(country);
  }

  updateWarning(country) {
    if (!this.hasWarningTarget) return;

    const itemType = this.itemTypeValue;
    let shouldShow = false;
    let message = "";

    switch (itemType) {
      case "us_origin":
        shouldShow = country !== null && country !== "United States";
        message = this.usOriginMessageValue;
        break;
      case "unknown_origin":
        shouldShow = true;
        message = this.unknownOriginMessageValue;
        break;
      default:
        shouldShow = false;
    }

    if (shouldShow && message) {
      this.warningTarget.textContent = message;
      this.warningTarget.style.display = "block";
    } else {
      this.warningTarget.style.display = "none";
    }
  }
}
