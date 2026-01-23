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
      this.dismissAd();
    }
  }

  dismissAd() {
    fetch("/my/dismiss_thing", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.getCsrfToken(),
      },
      body: JSON.stringify({ thing_name: "flagship_ad" }),
    }).catch((error) => console.error("Error dismissing ad:", error));
  }

  getCsrfToken() {
    const token = document.querySelector('meta[name="csrf-token"]');
    return token ? token.getAttribute("content") : "";
  }
}
