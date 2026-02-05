import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.element.addEventListener("click", this.select.bind(this));
  }

  disconnect() {
    this.element.removeEventListener("click", this.select.bind(this));
  }

  select() {
    const radioGroup = this.element.dataset.radiogroup;

    document
      .querySelectorAll(`[data-radiogroup="${radioGroup}"]`)
      .forEach((el) => {
        const isSelected = el === this.element;
        el.dataset.checked = isSelected ? "true" : "false";
        const hiddenInput = el.querySelector('input[type="hidden"]');
        if (hiddenInput) {
          hiddenInput.disabled = !isSelected;
        }
      });
  }
}
