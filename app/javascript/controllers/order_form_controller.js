import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "preview", "dropdown", "submitButton"];
  static values = { addresses: Array, hasAddresses: Boolean };

  connect() {
    if (!this.hasAddressesValue) {
      this.submitButtonTarget.disabled = true;
    }
    this.undo();
  }

  undo() {
    const radios = this.element.querySelectorAll(
      ".shop-order__accessory-option-input"
    );
    radios.forEach((radio) => {
      radio.addEventListener("click", (e) => {
        if (radio.dataset.wasChecked === "true") {
          radio.checked = false;
          radio.dataset.wasChecked = "false";
          radio.dispatchEvent(new Event("change", { bubbles: true }));
        } else {
          const same = this.element.querySelectorAll(
            `input[name="${radio.name}"]`
          );
          same.forEach((r) => (r.dataset.wasChecked = "false"));
          radio.dataset.wasChecked = "true";
        }
      });
    });
  }
}
