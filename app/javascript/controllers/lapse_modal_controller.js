import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    frameId: String,
    modalId: String,
    url: String,
    loaded: { type: Boolean, default: false },
  };

  connect() {
    this.element.addEventListener("click", this.open.bind(this));
  }

  open() {
    if (!this.loadedValue) {
      this.loadFrame();
    } else {
      this.showModal();
    }
  }

  loadFrame() {
    const frame = document.getElementById(this.frameIdValue);
    if (!frame) return;

    frame.src = this.urlValue;
    this.loadedValue = true;

    frame.addEventListener(
      "turbo:frame-load",
      () => {
        this.showModal();
      },
      { once: true },
    );
  }

  showModal() {
    const modal = document.getElementById(this.modalIdValue);
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
}
