import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    src: String,
    alt: String,
  };

  load(event) {
    event.preventDefault();
    const img = document.createElement("img");
    img.src = this.srcValue;
    img.alt = this.altValue || "";
    this.element.replaceWith(img);
  }
}
