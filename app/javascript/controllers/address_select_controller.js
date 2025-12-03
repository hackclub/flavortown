import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "preview", "dropdown"];
  static values = { addresses: Array };

  connect() {
    this.element.addEventListener("click", this.handleDropdownSelect.bind(this));
  }

  handleDropdownSelect(event) {
    const item = event.target.closest(".dropdown__item");
    if (!item) return;

    const addressId = item.dataset.value;
    this.inputTarget.value = addressId;

    const addresses = JSON.parse(this.element.dataset.addresses || "[]");
    const addr = addresses.find((a) => a.id === addressId);

    if (addr && this.hasPreviewTarget) {
      let html =
        "<p>" +
        addr.first_name +
        " " +
        addr.last_name +
        "<br>" +
        addr.line_1;
      if (addr.line_2) {
        html += "<br>" + addr.line_2;
      }
      html +=
        "<br>" +
        addr.city +
        ", " +
        addr.state +
        " " +
        addr.postal_code +
        "<br>" +
        addr.country +
        "</p>";
      this.previewTarget.innerHTML = html;
    }
  }
}
