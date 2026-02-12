import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    const hash = window.location.hash.slice(1);
    if (!hash) return;

    requestAnimationFrame(() => {
      const target = document.getElementById(hash);
      if (!target) return;

      target.scrollIntoView({ behavior: "smooth", block: "center" });
      target.classList.add("sidequest-card--highlighted");
      setTimeout(() => {
        target.classList.remove("sidequest-card--highlighted");
      }, 3000);
    });
  }
}
