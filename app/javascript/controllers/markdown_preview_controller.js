import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "preview"];
  static values = { url: String };

  connect() {
    this.update();
  }

  update() {
    const markdown = this.inputTarget.value || "";
    if (markdown.trim() === "") {
      this.previewTarget.innerHTML =
        '<span class="markdown-preview__empty">Preview will appear here...</span>';
      return;
    }

    clearTimeout(this.debounceTimer);
    this.debounceTimer = setTimeout(() => {
      this.fetchPreview(markdown);
    }, 300);
  }

  async fetchPreview(markdown) {
    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
            ?.content,
        },
        body: new URLSearchParams({ markdown }),
      });

      if (response.ok) {
        const html = await response.text();
        this.previewTarget.innerHTML =
          html || '<span class="markdown-preview__empty">Nothing to preview</span>';
      }
    } catch (error) {
      console.error("Markdown preview error:", error);
    }
  }
}
