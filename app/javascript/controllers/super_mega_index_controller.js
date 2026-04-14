import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["index"];

  connect() {
    if (!this.hasIndexTarget) return;
    this._handleHashChange = this.updateActiveFromUrl.bind(this);
    window.addEventListener("hashchange", this._handleHashChange);
    this.updateActiveFromUrl();
  }

  disconnect() {
    if (this._handleHashChange) {
      window.removeEventListener("hashchange", this._handleHashChange);
    }
  }

  scroll(event) {
    this.close();
    window.setTimeout(() => this.updateActiveFromUrl(), 0);
  }

  toggle(event) {
    event.preventDefault();
    const expanded = this.indexTarget.classList.toggle(
      "super-mega-dashboard__index--open",
    );
    this.indexTarget
      .querySelector(".super-mega-dashboard__index-handle")
      ?.setAttribute("aria-expanded", expanded ? "true" : "false");
  }

  close() {
    this.indexTarget.classList.remove("super-mega-dashboard__index--open");
    this.indexTarget
      .querySelector(".super-mega-dashboard__index-handle")
      ?.setAttribute("aria-expanded", "false");
  }

  updateActiveFromUrl() {
    const sectionId = window.location.hash?.replace(/^#/, "");
    this.setActive(sectionId || null);
  }

  setActive(sectionId) {
    const links = this.indexTarget.querySelectorAll(
      ".super-mega-dashboard__index-link",
    );
    links.forEach((link) => {
      const isActive = !!sectionId && link.dataset.sectionId === sectionId;
      link.classList.toggle(
        "super-mega-dashboard__index-link--active",
        isActive,
      );
      if (isActive) link.setAttribute("aria-current", "location");
      else link.removeAttribute("aria-current");
    });
  }
}
