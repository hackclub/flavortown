import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["info", "link", "sidequestMap"];
  static values = { preselected: Number };

  connect() {
    if (!this.hasSidequestMapTarget) {
      console.error("sidequestMap target not found!");
      return;
    }

    try {
      const mapText = this.sidequestMapTarget.textContent;
      this.sidequestMap = JSON.parse(mapText);
    } catch (e) {
      console.error("Error parsing sidequest map:", e);
      this.sidequestMap = {};
    }
    
    this.selectElement = this.element.querySelector("select");

    if (this.selectElement) {
      this.selectElement.addEventListener("change", (event) => {
        this.updateSidequestInfo();
      });
    } else {
      console.error("Could not find select element in controller!");
    }

    if (this.preselectedValue) {
      this.showInfo();
      this.updateLinkHref(this.preselectedValue.toString());
    }
  }

  updateSidequestInfo() {
    const selectedId = this.selectElement?.value;

    if (selectedId) {
      this.showInfo();
      this.updateLinkHref(selectedId);
    } else {
      this.hideInfo();
    }
  }

  showInfo() {
    if (this.hasInfoTarget) {
      this.infoTarget.style.display = "block";
    }
  }

  hideInfo() {
    if (this.hasInfoTarget) {
      this.infoTarget.style.display = "none";
    }
  }

  updateLinkHref(sidequestId) {
    if (this.hasLinkTarget && this.sidequestMap[sidequestId]) {
      this.linkTarget.href = this.sidequestMap[sidequestId];
    } else {
      console.warn("Sidequest ID not found in map or link target missing:", sidequestId);
    }
  }
}
