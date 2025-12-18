import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["track", "indicators", "prevButton", "nextButton"];

  connect() {
    this.index = 0;
    this.slides = this.hasTrackTarget
      ? Array.from(this.trackTarget.querySelectorAll(":scope > .post__slide"))
      : [];
    this.count = this.slides.length;
    this.#updateUi(true);
  }

  prev(event) {
    event?.preventDefault?.();
    event?.stopPropagation?.();
    if (this.count <= 1) return;
    this.index = (this.index - 1 + this.count) % this.count;
    this.#updateUi();
  }

  next(event) {
    event?.preventDefault?.();
    event?.stopPropagation?.();
    if (this.count <= 1) return;
    this.index = (this.index + 1) % this.count;
    this.#updateUi();
  }

  goTo(event) {
    event?.preventDefault?.();
    event?.stopPropagation?.();
    const i = Number(event?.currentTarget?.dataset?.index ?? -1);
    if (Number.isNaN(i) || i < 0 || i >= this.count) return;
    this.index = i;
    this.#updateUi();
  }

  #updateUi(initial = false) {
    // Move track
    if (this.hasTrackTarget) {
      const offset = -(this.index * 100);
      this.trackTarget.style.transform = `translateX(${offset}%)`;
    }
    const many = this.count > 1;
    if (this.hasPrevButtonTarget) this.prevButtonTarget.hidden = !many;
    if (this.hasNextButtonTarget) this.nextButtonTarget.hidden = !many;
    if (this.hasIndicatorsTarget) {
      if (!many) {
        this.indicatorsTarget.hidden = true;
        if (!initial) this.indicatorsTarget.innerHTML = "";
      } else {
        this.indicatorsTarget.hidden = false;
        // render dots
        this.indicatorsTarget.innerHTML = Array.from({ length: this.count })
          .map(
            (_p, i) =>
              `<button type="button" class="post__dot${
                i === this.index ? " is-active" : ""
              }" data-index="${i}" data-action="post-attachments#goTo" aria-label="Show attachment ${i + 1}"></button>`,
          )
          .join("");
      }
    }
  }
}
