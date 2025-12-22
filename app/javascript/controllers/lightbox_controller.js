import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["image"];

  connect() {
    this.overlay = null;
  }

  open(event) {
    event.preventDefault();
    event.stopPropagation();
    const target = event.currentTarget;
    const img = target.tagName === "IMG" ? target : target.querySelector("img");
    const src = target.dataset.lightboxSrc || img?.dataset.lightboxSrc || img?.src;

    this.overlay = document.createElement("div");
    this.overlay.className = "lightbox-overlay";
    this.overlay.innerHTML = `
      <div class="lightbox-content">
        <button type="button" class="lightbox-close" aria-label="Close">&times;</button>
        <img src="${src}" alt="Full size image" class="lightbox-image">
      </div>
    `;

    this.overlay.addEventListener("click", (e) => {
      if (e.target === this.overlay || e.target.classList.contains("lightbox-close")) {
        this.close();
      }
    });

    document.addEventListener("keydown", this.handleKeydown);
    document.body.appendChild(this.overlay);
    document.body.style.overflow = "hidden";
  }

  handleKeydown = (event) => {
    if (event.key === "Escape") {
      this.close();
    }
  };

  close() {
    if (this.overlay) {
      this.overlay.remove();
      this.overlay = null;
      document.body.style.overflow = "";
      document.removeEventListener("keydown", this.handleKeydown);
    }
  }

  disconnect() {
    this.close();
  }
}
