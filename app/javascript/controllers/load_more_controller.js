import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["entries", "button", "sentinel"];
  static values = { url: String };

  connect() {
    this.setupInfiniteScroll();
  }

  disconnect() {
    this.disconnectObserver();
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
      { rootMargin: "200px" },
    );

    this.observer.observe(this.sentinelTarget);
  }

  async load(event) {
    event.preventDefault();
    event.stopPropagation();
    await this.loadMore();
  }

  async loadMore() {
    const target = this.loadTarget;
    if (!target || this.loading) return;

    const nextPage = target.dataset.page;
    if (!nextPage) return;

    this.loading = true;
    this.setLoadingState();

    try {
      const data = await this.fetchPage(nextPage);
      this.entriesTarget.insertAdjacentHTML("beforeend", data.html);

      if (data.next_page) {
        this.updateNextPage(data.next_page);
      } else {
        this.showEndMessage();
      }
    } catch {
      this.showError();
    } finally {
      this.loading = false;
    }
  }

  get loadTarget() {
    return this.hasButtonTarget
      ? this.buttonTarget
      : this.hasSentinelTarget
        ? this.sentinelTarget
        : null;
  }

  async fetchPage(page) {
    const url = new URL(
      this.urlValue || window.location.href,
      window.location.origin,
    );
    url.searchParams.set("page", page);
    url.searchParams.set("format", "json");

    const response = await fetch(url, {
      headers: {
        Accept: "application/json",
        "X-Requested-With": "XMLHttpRequest",
      },
    });

    if (!response.ok) throw new Error("Failed to load");
    return response.json();
  }

  setLoadingState() {
    if (this.hasButtonTarget) {
      this.buttonTarget.textContent = "Loading...";
      this.buttonTarget.disabled = true;
    }
  }

  updateNextPage(page) {
    if (this.hasButtonTarget) {
      this.buttonTarget.dataset.page = page;
      this.buttonTarget.textContent = "Load More Devlogs";
      this.buttonTarget.disabled = false;
    }
    if (this.hasSentinelTarget) {
      this.sentinelTarget.dataset.page = page;
    }
  }

  showEndMessage() {
    const endElement = Object.assign(document.createElement("p"), {
      className: "explore__end",
      textContent: "You've reached the end.",
    });

    if (this.hasButtonTarget) {
      this.buttonTarget.replaceWith(endElement);
    } else if (this.hasSentinelTarget) {
      this.sentinelTarget.replaceWith(endElement);
      this.disconnectObserver();
    }
  }

  showError() {
    if (this.hasButtonTarget) {
      this.buttonTarget.textContent = "Failed to load. Try again?";
      this.buttonTarget.disabled = false;
    } else if (this.hasSentinelTarget) {
      this.sentinelTarget.textContent = "Failed to load more devlogs.";
      this.sentinelTarget.classList.add("explore__error");
      this.disconnectObserver();
    }
  }

  disconnectObserver() {
    if (this.observer) {
      this.observer.disconnect();
      this.observer = null;
    }
  }
}
