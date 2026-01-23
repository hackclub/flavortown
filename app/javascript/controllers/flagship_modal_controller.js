import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  open(event) {
    event.preventDefault();
    const modal = document.getElementById("flagship-modal");
    if (modal) {
      modal.showModal();
      document.body.style.overflow = "hidden";

      // Handle backdrop click
      modal.addEventListener("click", (e) => {
        if (e.target === modal) {
          this.close(e);
        }
      });

      // Handle escape key
      modal.addEventListener("cancel", (e) => {
        e.preventDefault();
        this.close(e);
      });
    }
  }

  close(event) {
    if (event) {
      event.preventDefault();
      event.stopPropagation();
    }
    const modal = document.getElementById("flagship-modal");
    if (modal) {
      modal.close();
      document.body.style.overflow = "";
    }

  }

  dismissAd() {
    // Hide the ad button immediately
    const adButton = document.querySelector(".kitchen-index__ad");
    if (adButton) {
      adButton.style.display = "none";
    }

    const formData = new FormData();
    formData.append("thing_name", "flagship_ad");

    fetch("/my/dismiss_thing", {
      method: "POST",
      headers: {
        "X-CSRF-Token": this.getCsrfToken(),
      },
      body: formData,
    }).catch((error) => console.error("Error dismissing ad:", error));
  }

  getCsrfToken() {
    const token = document.querySelector('meta[name="csrf-token"]');
    return token ? token.getAttribute("content") : "";
  }
}
