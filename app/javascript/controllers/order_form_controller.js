import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "preview", "dropdown", "submitButton"];
  static values = { addresses: Array, hasAddresses: Boolean };

  connect() {
    if (!this.hasAddressesValue) {
      this.submitButtonTarget.disabled = true;
    }
  }
}
