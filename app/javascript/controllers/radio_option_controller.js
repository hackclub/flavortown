import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { name: String, value: String };

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

    this.updateHiddenInput();
  }

  updateHiddenInput() {
    const name = this.nameValue;
    let input = document.querySelector(
      `input[type="hidden"][name="${name}"][data-radio-group-input]`,
    );

    if (!input) {
      input = document.createElement("input");
      input.type = "hidden";
      input.name = name;
      input.dataset.radioGroupInput = "true";
      this.element.closest("form")?.appendChild(input);
    }

    input.value = this.valueValue;
  }
}
