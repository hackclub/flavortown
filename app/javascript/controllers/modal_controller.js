import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { target: String };

  connect() {
    this._boundBackdropClick = this.backdropClick.bind(this);

    if (!this.hasTargetValue) {
      this.element.addEventListener("click", this._boundBackdropClick);
    }
  }

  disconnect() {
    if (!this.hasTargetValue) {
      this.element.removeEventListener("click", this._boundBackdropClick);
    }
  }

  open() {
    const modal = document.getElementById(this.targetValue);
    if (!modal) return;

    if (modal.tagName === "DIALOG") {
      modal.showModal();
    } else {
      modal.style.display = "flex";
      requestAnimationFrame(() => {
        modal.classList.add("lapse-modal--open");
      });
    }

    document.body.style.overflow = "hidden";
  }

  close() {
    if (this.element.tagName === "DIALOG") {
      this.element.close();
      document.body.style.overflow = "";
      return;
    }

    if (this.hasTargetValue) {
      const modal = document.getElementById(this.targetValue);
      if (modal) {
        if (modal.tagName === "DIALOG") {
          modal.close();
        } else {
          modal.classList.remove("lapse-modal--open");
          modal.classList.add("lapse-modal--closing");
          modal.addEventListener(
            "animationend",
            () => {
              modal.style.display = "none";
              modal.classList.remove("lapse-modal--closing");
            },
            { once: true },
          );
        }
      }
      document.body.style.overflow = "";
      return;
    }

    this.element.classList.remove("lapse-modal--open");
    this.element.classList.add("lapse-modal--closing");
    this.element.addEventListener(
      "animationend",
      () => {
        this.element.style.display = "none";
        this.element.classList.remove("lapse-modal--closing");
      },
      { once: true },
    );
    document.body.style.overflow = "";
  }

  backdropClick(event) {
    if (this.element.tagName !== "DIALOG") {
      if (event.target === this.element) this.close();
      return;
    }

    const rect = this.element.getBoundingClientRect();
    const clickedInside =
      event.clientX >= rect.left &&
      event.clientX <= rect.right &&
      event.clientY >= rect.top &&
      event.clientY <= rect.bottom;

    if (!clickedInside) this.close();
  }
}
