import { Controller } from "@hotwired/stimulus";

const sections = [
  { id: "funnel", label: "Funnel" },
  { id: "nps", label: "NPS" },
  { id: "hcb", label: "HCB" },
  { id: "fraud", label: "Fraud" },
  { id: "payouts", label: "Payouts" },
  { id: "fulfillment", label: "Fulfillment" },
  { id: "shipwrights", label: "Shipwrights" },
  { id: "support", label: "Support" },
  { id: "ysws_review", label: "YSWS Review" },
  { id: "voting", label: "Voting" },
  { id: "community", label: "Community" },
  { id: "pyramid_flavortime", label: "Pyramid / Flavortime" },
  { id: "sidequests", label: "Sidequests" },
];

export default class extends Controller {
  static targets = ["toc"];
  static values = {
    offset: { type: Number, default: 0 },
  };

  connect() {
    if (!this.hasTocTarget) return;

    this.sectionConfigs = sections;
    this.sectionElements = this.sectionConfigs
      .map(({ id }) => this.findSectionElement(id))
      .filter(Boolean);

    this.render();
    this.installObserver();

    // If a hash is present, honor it using the same offset logic.
    const hashId = window.location.hash?.replace(/^#/, "");
    if (hashId) {
      const el = this.findSectionElement(hashId);
      if (el) this.scrollToSection(el, { behavior: "auto" });
    }
  }

  disconnect() {
    this.observer?.disconnect();
  }

  scroll(event) {
    event.preventDefault();

    const link = event.currentTarget;
    const sectionId = link?.dataset?.sectionId;
    if (!sectionId) return;

    const el = this.findSectionElement(sectionId);
    if (!el) return;

    this.setActive(sectionId);
    this.scrollToSection(el, { behavior: "smooth" });

    // Preserve shareable URL.
    try {
      history.replaceState(null, "", `#${sectionId}`);
    } catch {
      // no-op
    }
  }

  toggle(event) {
    event.preventDefault();

    this.tocTarget.classList.toggle("super-mega-dashboard__toc--open");

    const handle = this.tocTarget.querySelector(
      ".super-mega-dashboard__toc-handle",
    );
    if (!handle) return;

    const expanded = this.tocTarget.classList.contains(
      "super-mega-dashboard__toc--open",
    );
    handle.setAttribute("aria-expanded", expanded ? "true" : "false");
  }

  render() {
    const items = this.sectionConfigs
      .map(({ id, label }) => {
        const exists = Boolean(this.findSectionElement(id));
        if (!exists) return "";

        return `
          <li class="super-mega-dashboard__toc-item">
            <a
              class="super-mega-dashboard__toc-link"
              href="#${id}"
              data-action="super-mega-dashboard-toc#scroll"
              data-section-id="${id}"
            >${this.escapeHtml(label)}</a>
          </li>
        `;
      })
      .join("");

    this.tocTarget.innerHTML = `
      <button
        type="button"
        class="super-mega-dashboard__toc-handle"
        aria-controls="super-mega-dashboard__toc-nav"
      >
        <span class="super-mega-dashboard__toc-handle-label">Super Mega Index</span>
      </button>
      <div class="super-mega-dashboard__toc-content">
        <nav
          id="super-mega-dashboard__toc-nav"
          class="super-mega-dashboard__toc-nav"
          aria-label="On this page"
        >
          <div class="super-mega-dashboard__toc-title">On this page</div>
          <ol class="super-mega-dashboard__toc-list">${items}</ol>
        </nav>
      </div>
    `;

    // Default the active state to the first section.
    const firstExisting = this.sectionConfigs.find(({ id }) =>
      this.findSectionElement(id),
    );
    if (firstExisting) this.setActive(firstExisting.id);
  }

  installObserver() {
    if (!this.sectionElements.length) return;

    const offset = this.totalOffset();
    const rootMarginTop = -(offset + 12);

    this.observer = new IntersectionObserver(
      (entries) => {
        const visible = entries
          .filter((e) => e.isIntersecting)
          .sort(
            (a, b) => (b.intersectionRatio ?? 0) - (a.intersectionRatio ?? 0),
          );

        const top = visible[0];
        const newActiveId = top?.target?.id;
        if (newActiveId) this.setActive(newActiveId);
      },
      {
        // The negative top margin accounts for fixed headers.
        rootMargin: `${rootMarginTop}px 0px -70% 0px`,
        threshold: [0.05, 0.1, 0.2, 0.35, 0.5, 0.65, 0.8],
      },
    );

    this.sectionElements.forEach((el) => this.observer.observe(el));
  }

  setActive(sectionId) {
    if (this.activeSectionId === sectionId) return;
    this.activeSectionId = sectionId;

    const links = this.tocTarget.querySelectorAll(
      ".super-mega-dashboard__toc-link",
    );
    links.forEach((link) => {
      const isActive = link.dataset.sectionId === sectionId;
      link.classList.toggle("super-mega-dashboard__toc-link--active", isActive);
      if (isActive) {
        link.setAttribute("aria-current", "location");
        // Keep the active link visible when the TOC itself scrolls.
        link.scrollIntoView({ block: "nearest" });
      } else {
        link.removeAttribute("aria-current");
      }
    });
  }

  scrollToSection(el, { behavior }) {
    const offset = this.totalOffset();
    const y = el.getBoundingClientRect().top + window.scrollY - offset;

    window.scrollTo({ top: y, behavior });
  }

  findSectionElement(id) {
    if (!id) return null;

    // Scope to the dashboard element to avoid collisions elsewhere in the DOM.
    try {
      return this.element.querySelector(`#${CSS.escape(id)}`);
    } catch {
      return this.element.querySelector(`#${id}`);
    }
  }

  totalOffset() {
    let offset = this.offsetValue || 0;

    const impersonationBanner = document.querySelector(".impersonation-banner");
    if (impersonationBanner) {
      const styles = window.getComputedStyle(impersonationBanner);
      const isFixed =
        styles.position === "fixed" || styles.position === "sticky";
      if (isFixed) offset += impersonationBanner.getBoundingClientRect().height;
    }

    return offset;
  }

  escapeHtml(input) {
    return String(input)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;");
  }
}
