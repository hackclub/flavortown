import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["periodSelect"];

  updatePeriod(event) {
    event.preventDefault();
    const form = this.periodSelectTarget.closest("form");
    if (form) {
      form.requestSubmit();
    }
  }
}
