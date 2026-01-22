import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["image", "map"];

  connect() {
    this._onResize = this.remap.bind(this);

    if (this.imageTarget.complete) {
      this.remap();
    } else {
      this.imageTarget.addEventListener("load", () => this.remap(), { once: true });
    }

    window.addEventListener("resize", this._onResize);
  }

  disconnect() {
    window.removeEventListener("resize", this._onResize);
  }

  remap() {
    const img = this.imageTarget;
    const map = this.mapTarget;
    if (!img.naturalWidth || !img.naturalHeight) return;

    const scaleX = img.clientWidth / img.naturalWidth;
    const scaleY = img.clientHeight / img.naturalHeight;

    const areas = map.querySelectorAll("area");
    areas.forEach((area) => {
      const original = area.dataset.originalCoords || area.getAttribute("coords");
      area.dataset.originalCoords = original;

      const nums = original.split(",").map((n) => Number.parseFloat(n));
      const scaled = nums.map((n, idx) => (idx % 2 === 0 ? n * scaleX : n * scaleY));

      area.setAttribute("coords", scaled.map((n) => Math.round(n)).join(","));
    });
  }
}