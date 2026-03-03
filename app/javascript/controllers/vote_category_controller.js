import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["score"];

  connect() {
    this.selectedScore = this.selectedInputValue();
    this.renderScore(this.selectedScore);
  }

  updateScore(event) {
    this.selectedScore = event.target.value;
    this.renderScore(this.selectedScore);
  }

  selectedInputValue() {
    return (
      this.element.querySelector(".vote-category__input:checked")?.value || null
    );
  }

  renderScore(rawValue) {
    if (!rawValue) {
      this.scoreTarget.textContent = "-";
      return;
    }

    this.scoreTarget.textContent = `${Number(rawValue)}/9`;
  }
}
