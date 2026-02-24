import { Controller } from "@hotwired/stimulus"

// This controller defers non-critical dashboard sections to load on scroll
// Keeps initial page load fast by splitting data loading
export default class extends Controller {
  connect() {
    // Immediately visible sections load right away
    this.loadImmediatelyVisibleSections()
    
    // Setup observer for sections that come into view
    this.setupIntersectionObserver()
  }

  setupIntersectionObserver() {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          const section = entry.target.dataset.lazySection
          if (section && !entry.target.dataset.loaded) {
            this.reloadSection(section)
            observer.unobserve(entry.target)
          }
        }
      })
    }, { rootMargin: "200px" })

    // Observe all lazy-loadable sections
    document.querySelectorAll("[data-lazy-section]").forEach(el => {
      if (!el.dataset.loaded) {
        observer.observe(el)
      }
    })
  }

  loadImmediatelyVisibleSections() {
    // Load sections that are in viewport immediately (fraud, voting)
    document.querySelectorAll("[data-lazy-section]").forEach(el => {
      if (!el.dataset.loaded && this.isInViewport(el)) {
        const section = el.dataset.lazySection
        this.reloadSection(section)
      }
    })
  }

  isInViewport(el) {
    const rect = el.getBoundingClientRect()
    return rect.top < window.innerHeight + 100 && rect.bottom > -100
  }

  reloadSection(section) {
    const container = document.querySelector(`[data-lazy-section="${section}"]`)
    if (!container) return

    const url = `/admin/super_mega_dashboard/load_section?section=${section}`
    
    fetch(url)
      .then(response => response.text())
      .then(html => {
        container.innerHTML = html
        container.dataset.loaded = "true"
        // Dispatch event in case any JS needs to initialize charts, etc.
        container.dispatchEvent(new CustomEvent("section-loaded", { detail: { section } }))
      })
      .catch(error => {
        console.error(`Failed to load section ${section}:`, error)
      })
  }
}
