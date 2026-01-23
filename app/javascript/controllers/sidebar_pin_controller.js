import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["button"];
  static classes = ["pinned"];

  connect() {
    if (localStorage.getItem("sidebarPinned") === "true") {
      this.element.classList.add(this.pinnedClass);
    }
  }

  toggle() {
    const isPinned = this.element.classList.toggle(this.pinnedClass);
    localStorage.setItem("sidebarPinned", isPinned);
  }
}
