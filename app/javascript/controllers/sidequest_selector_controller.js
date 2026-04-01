import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["select", "info", "link", "sidequestMap"];

  connect() {
    this.updateInfoVisibility();
    this.updateLink();
  }

  selectChange() {
    this.updateInfoVisibility();
    this.updateLink();
  }

  updateInfoVisibility() {
    if (!this.hasInfoTarget || !this.hasSelectTarget) return;

    this.infoTarget.style.display = this.selectTarget.value ? "block" : "none";
  }

  updateLink() {
    if (!this.hasLinkTarget || !this.hasSelectTarget) return;

    const selectedId = this.selectTarget.value;
    if (!selectedId) {
      this.linkTarget.href = "#";
      return;
    }

    const path = this.sidequestMapData()[selectedId];
    this.linkTarget.href = path || "#";
  }

  sidequestMapData() {
    if (!this.hasSidequestMapTarget) return {};

    try {
      return JSON.parse(this.sidequestMapTarget.textContent || "{}");
    } catch (_error) {
      return {};
    }
  }
}
