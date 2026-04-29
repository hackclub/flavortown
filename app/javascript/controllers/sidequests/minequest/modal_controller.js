import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["dialog"];

  open(e) {
    e.preventDefault();
    this.dialogTarget.classList.remove("hidden");
  }

  close(e) {
    e.preventDefault();
    this.dialogTarget.classList.add("hidden");
  }
}
