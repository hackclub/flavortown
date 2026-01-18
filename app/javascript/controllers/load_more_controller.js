import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["entries", "button", "sentinel"];
  static values = { url: String };

  connect() {
    this.setupInfiniteScroll();
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect();
    }
  }

  setupInfiniteScroll() {
    if (!this.hasSentinelTarget) return;

    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting && !this.loading) {
            this.loadMore();
          }
        });
      },
      {
        rootMargin: "200px",
      },
    );

    this.observer.observe(this.sentinelTarget);
  }

  async load(event) {
    event.preventDefault();
    event.stopPropagation();
    await this.loadMore();
  }

  async loadMore() {
    const nextPage = this.hasButtonTarget
      ? this.buttonTarget.dataset.page
      : this.sentinelTarget?.dataset.page;

    if (!nextPage || this.loading) return;

    this.loading = true;

    if (this.hasButtonTarget) {
      this.buttonTarget.textContent = "Loading...";
      this.buttonTarget.disabled = true;
    }

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
        if (this.hasButtonTarget) {
          this.buttonTarget.dataset.page = data.next_page;
          this.buttonTarget.textContent = "Load More Devlogs";
          this.buttonTarget.disabled = false;
        }
        if (this.hasSentinelTarget) {
          this.sentinelTarget.dataset.page = data.next_page;
        }
      } else {
        if (this.hasButtonTarget) {
          this.buttonTarget.replaceWith(
            Object.assign(document.createElement("p"), {
              className: "explore__end",
              textContent: "You've reached the end.",
            }),
          );
        }
        if (this.hasSentinelTarget) {
          this.sentinelTarget.replaceWith(
            Object.assign(document.createElement("p"), {
              className: "explore__end",
              textContent: "You've reached the end.",
            }),
          );
          if (this.observer) {
            this.observer.disconnect();
          }
        }
      }
    } catch (error) {
      if (this.hasButtonTarget) {
        this.buttonTarget.textContent = "Failed to load. Try again?";
        this.buttonTarget.disabled = false;
      }
      if (this.hasSentinelTarget) {
        this.sentinelTarget.textContent = "Failed to load more devlogs.";
        if (this.sentinelTarget.classList) {
          this.sentinelTarget.classList.add("explore__error");
        }
        if (this.observer) {
          this.observer.disconnect();
        }
      }
    } finally {
      this.loading = false;
    }
  }
}
