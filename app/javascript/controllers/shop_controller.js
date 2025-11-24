import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["sortBtn", "items"];

  connect() {
    this.sortAscending = true;
    this.setupSortButton();
  }

  setupSortButton() {
    const sortBtn = document.getElementById("sort-btn");
    if (sortBtn) {
      sortBtn.addEventListener("click", () => this.toggleSort());
    }
  }

  toggleSort() {
    this.sortAscending = !this.sortAscending;
    this.sortItems();
  }

  sortItems() {
    const itemsContainer = document.querySelector(".shop__items");
    if (!itemsContainer) return;

    const items = Array.from(
      itemsContainer.querySelectorAll(".shop-item-card"),
    );

    items.sort((a, b) => {
      const priceA = this.extractPrice(a);
      const priceB = this.extractPrice(b);

      return this.sortAscending ? priceA - priceB : priceB - priceA;
    });

    items.forEach((item) => itemsContainer.appendChild(item));
  }

  extractPrice(element) {
    const priceText = element.querySelector(
      ".shop-item-card__price",
    )?.textContent;
    if (!priceText) return 0;
    const match = priceText.match(/[\d.]+/);
    return match ? parseFloat(match[0]) : 0;
  }
}
