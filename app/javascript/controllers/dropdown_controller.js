import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["button", "menu", "selected"];

  toggle(event) {
    event.preventDefault();
    this.menuTarget.classList.toggle("dropdown__menu--open");
  }

  select(event) {
    const option = event.target.textContent;
    this.selectedTarget.textContent = option;
    this.menuTarget.classList.remove("dropdown__menu--open");

    // Trigger filtering if label is Category, Price Range, or Sort by
    const label = this.element.querySelector(".dropdown__label")?.textContent;
    if (label === "Category") {
      this.filterByCategory(option);
    } else if (label === "Price Range") {
      this.filterByPrice(option);
    } else if (label === "Sort by") {
      this.sortBy(option);
    }
  }

  filterByCategory(category) {
    const items = document.querySelectorAll(".shop-item-card");
    items.forEach((item) => {
      if (category === "Grants") {
        item.style.display = "flex";
      } else if (category === "Warehouse") {
        item.style.display = "flex";
      } else if (category === "Third Party") {
        item.style.display = "flex";
      }
    });
  }

  filterByPrice(range) {
    const items = document.querySelectorAll(".shop-item-card");
    const [min, max] = this.getPriceRange(range);

    items.forEach((item) => {
      const priceText = item.querySelector(
        ".shop-item-card__price",
      )?.textContent;
      if (!priceText) {
        item.style.display = "flex";
        return;
      }
      const match = priceText.match(/[\d.]+/);
      const price = match ? parseFloat(match[0]) : 0;
      item.style.display = price >= min && price <= max ? "flex" : "none";
    });
  }

  getPriceRange(range) {
    if (range.includes("$0")) return [0, 100000];
    if (range.includes("$100,000 - $500,000")) return [100000, 500000];
    if (range.includes(">$500,000")) return [500000, Infinity];
    return [0, Infinity];
  }

  sortBy(sortType) {
    const itemsContainer = document.querySelector(".shop__items");
    if (!itemsContainer) return;

    const items = Array.from(
      itemsContainer.querySelectorAll(".shop-item-card"),
    );

    if (sortType === "Prices") {
      items.sort((a, b) => {
        const priceA = this.extractPrice(a);
        const priceB = this.extractPrice(b);
        return priceA - priceB;
      });
    } else if (sortType === "Alphabetical") {
      items.sort((a, b) => {
        const nameA =
          a.querySelector(".shop-item-card__title")?.textContent || "";
        const nameB =
          b.querySelector(".shop-item-card__title")?.textContent || "";
        return nameA.localeCompare(nameB);
      });
    }

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

  disconnect() {
    this.menuTarget?.classList.remove("dropdown__menu--open");
  }
}
