import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { slug: String };
  static targets = ["card"];

  connect() {
    if (!this.slugValue) return;

    requestAnimationFrame(() => this.highlightCard());
  }

  highlightCard() {
    const targetCard = this.cardTargets.find(
      (card) => card.dataset.slug === this.slugValue
    );
    if (targetCard) {
      targetCard.scrollIntoView({ behavior: "smooth", block: "center" });
      targetCard.classList.add("achievements__card--highlighted");
      setTimeout(() => {
        targetCard.classList.add("achievements__card--fading");
        setTimeout(() => {
          targetCard.classList.remove(
            "achievements__card--highlighted",
            "achievements__card--fading"
          );
        }, 500);
      }, 2500);
    }
  }
}
