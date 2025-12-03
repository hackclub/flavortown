import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["button", "menu", "selected"];

  toggle(event) {
    event.preventDefault();
    this.menuTarget.classList.toggle("dropdown__menu--open");
  }

  select(event) {
    const option = event.target.textContent;
    const value = event.target.dataset.value || option;
    this.selectedTarget.textContent = option;
    this.menuTarget.classList.remove("dropdown__menu--open");

    const label = this.element.querySelector(".dropdown__label")?.textContent;

    if (
      label === "Category" ||
      label === "Price Range" ||
      label === "Sort by" ||
      label === "Region"
    ) {
      document.dispatchEvent(
        new CustomEvent("shop:filter", {
          detail: { filterType: label, value: value },
        }),
      );
    }
  }

  disconnect() {
    this.menuTarget?.classList.remove("dropdown__menu--open");
  }
}
