import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["content", "button", "buttonText"];

  connect() {
    this.expanded = false;

    if (window.location.hash === `#${this.element.id}`) {
      this.expand();
      this.element.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  }

  toggle() {
    if (this.expanded) {
      this.collapse();
    } else {
      this.expand();
    }
  }

  expand() {
    this.expanded = true;
    this.contentTarget.classList.add("sidequest-card__expanded--open");
    this.buttonTextTarget.textContent = "Close Briefing";
    this.element.classList.add("sidequest-card--expanded");
  }

  collapse() {
    this.expanded = false;
    this.contentTarget.classList.remove("sidequest-card__expanded--open");
    this.buttonTextTarget.textContent = "Mission Briefing";
    this.element.classList.remove("sidequest-card--expanded");
  }
}
