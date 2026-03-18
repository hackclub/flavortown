import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            this.loadSection(entry.target);
            this.observer.unobserve(entry.target);
          }
        });
      },
      { rootMargin: "200px" },
    );

    this.element
      .querySelectorAll("[data-lazy-section]")
      .forEach((el) => this.observer.observe(el));
  }

  disconnect() {
    this.observer?.disconnect();
  }

  async loadSection(el) {
    const section = el.dataset.lazySection;
    try {
      const response = await fetch(
        `/admin/super_mega_dashboard/load_section?section=${encodeURIComponent(section)}`,
      );
      if (!response.ok) return;
      el.innerHTML = await response.text();
      await this.activateScripts(el);
    } catch (e) {
      console.error("[lazy-load] failed to load section:", section, e);
    }
  }

  async activateScripts(container) {
    const scripts = [...container.querySelectorAll("script")];

    for (const script of scripts) {
      const parent = script.parentNode;
      if (!parent) continue;

      const fresh = document.createElement("script");

      // Copy all attributes (src, type, async, etc.) to the new script element.
      for (const { name, value } of [...script.attributes]) {
        fresh.setAttribute(name, value);
      }

      if (fresh.src) {
        // Lazily initialize the set of already-loaded script srcs.
        if (!this.loadedScriptSrcs) {
          this.loadedScriptSrcs = new Set();
        }

        // Skip loading the same external script multiple times.
        if (this.loadedScriptSrcs.has(fresh.src)) {
          parent.removeChild(script);
          continue;
        }

        this.loadedScriptSrcs.add(fresh.src);

        await new Promise((resolve) => {
          fresh.onload = resolve;
          fresh.onerror = resolve;
          parent.replaceChild(fresh, script);
        });
      } else {
        // Inline script: avoid eval/new Function; let the browser execute it
        // by inserting a fresh <script> node with the same contents.
        fresh.textContent = script.textContent;
        parent.replaceChild(fresh, script);
      }
    }
  }
}
