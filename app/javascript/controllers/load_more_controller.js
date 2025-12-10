import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["entries", "button"];
  static values = { url: String };

  async load(event) {
    event.preventDefault();
    event.stopPropagation();

    const button = event.currentTarget;
    const nextPage = button.dataset.page;

    if (!nextPage) return;

    const originalText = button.textContent;
    button.textContent = "Loading...";
    button.disabled = true;

    try {
      const url = new URL(
        this.urlValue || window.location.href,
        window.location.origin,
      );
      url.searchParams.set("page", nextPage);
      url.searchParams.set("format", "json");

      const response = await fetch(url, {
        headers: {
          Accept: "application/json",
          "X-Requested-With": "XMLHttpRequest",
        },
      });

      if (!response.ok) throw new Error("Failed to load");

      const data = await response.json();

      this.entriesTarget.insertAdjacentHTML("beforeend", data.html);

      if (data.next_page) {
        button.dataset.page = data.next_page;
        button.textContent = originalText;
        button.disabled = false;
      } else {
        button.replaceWith(
          Object.assign(document.createElement("p"), {
            className: "explore__end",
            textContent: "No more devlogs.",
          }),
        );
      }
    } catch (error) {
      button.textContent = "Failed to load. Try again?";
      button.disabled = false;
    }
  }
}
