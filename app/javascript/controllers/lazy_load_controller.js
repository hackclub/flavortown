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
    } catch {}
  }

  async activateScripts(container) {
    const scripts = [...container.querySelectorAll("script")];
    for (const script of scripts) {
      if (script.src) {
        await new Promise((resolve) => {
          const fresh = document.createElement("script");
          fresh.src = script.src;
          fresh.onload = resolve;
          fresh.onerror = resolve;
          document.head.appendChild(fresh);
        });
      } else {
        try {
          new Function(script.textContent)();
        } catch (e) {
          console.error("[lazy-load] inline script error:", e);
        }
      }
    }
  }
}
