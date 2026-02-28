import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["score"];

  updateScore(event) {
    this.scoreTarget.textContent = `${event.target.value}/9`;
  }
}
