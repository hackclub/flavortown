import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    if (!this.element.open) {
      this.element.showModal();
    }
  }

  bypass() {
    const form = document.getElementById("ship-form");
    if (!form) return;

    const input = document.createElement("input");
    input.type = "hidden";
    input.name = "bypass_ai_review";
    input.value = "1";
    form.appendChild(input);

    form.requestSubmit();
  }
}
