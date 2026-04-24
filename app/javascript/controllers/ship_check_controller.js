import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {}

  reset() {
    this.finishButton.disabled = false;
    this.finishButton.innerText = this.originalButtonText;
  }

  async runCheck() {
    const resp = await fetch("./pre_check");
    if (resp.ok) return true;

    this.dialog.innerHTML = await resp.text();
    this.dialog.showModal();
    return false;
  }

  shipIt() {
    this.finishButton.disabled = true;
    this.finishButton.innerText = "Shipping...";
    this.entireForm.requestSubmit();
  }

  async checkAndSubmit() {
    this.finishButton.disabled = true;
    this.finishButton.innerText = "Checking...";

    const isOk = await this.runCheck();
    if (!isOk) {
      this.reset();
      return;
    }
    this.shipIt();
  }

  check() {
    this.finishButton = this.element.querySelector(".ship-finish-button");
    this.entireForm = this.element.querySelector("#ship-form");
    this.dialog = this.element.querySelector("#ai-review-modal");
    this.originalButtonText = this.finishButton.innerText;

    if (!this.entireForm.reportValidity()) return;
    void this.checkAndSubmit();
  }

  shipAnyway() {
    this.finishButton = this.element.querySelector(".ship-finish-button");
    this.entireForm = this.element.querySelector("#ship-form");
    this.dialog = this.element.querySelector("#ai-review-modal");

    this.dialog.close();
    this.shipIt();
  }
}
