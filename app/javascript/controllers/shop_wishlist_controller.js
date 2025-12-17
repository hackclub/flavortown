import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["starButton", "goalSection", "goalItems"];
  static values = {
    itemId: String,
    itemName: String,
    itemPrice: Number,
    itemImage: String,
    balance: Number,
  };

  static STORAGE_KEY = "shop_wishlist";

  connect() {
    this.updateStarState();
  }

  getWishlist() {
    try {
      const data = localStorage.getItem(this.constructor.STORAGE_KEY);
      return data ? JSON.parse(data) : {};
    } catch {
      return {};
    }
  }

  saveWishlist(wishlist) {
    localStorage.setItem(this.constructor.STORAGE_KEY, JSON.stringify(wishlist));
    this.dispatch("updated", { detail: { wishlist } });
  }

  isStarred() {
    const wishlist = this.getWishlist();
    return !!wishlist[this.itemIdValue];
  }

  toggle(event) {
    event.preventDefault();
    event.stopPropagation();

    const wishlist = this.getWishlist();

    if (wishlist[this.itemIdValue]) {
      delete wishlist[this.itemIdValue];
    } else {
      wishlist[this.itemIdValue] = {
        id: this.itemIdValue,
        name: this.itemNameValue,
        price: this.itemPriceValue,
        image: this.itemImageValue,
        addedAt: new Date().toISOString(),
      };
    }

    this.saveWishlist(wishlist);
    this.updateStarState();
  }

  updateStarState() {
    if (!this.hasStarButtonTarget) return;

    const isStarred = this.isStarred();
    this.starButtonTarget.classList.toggle(
      "shop-item-card__star--active",
      isStarred
    );
    this.starButtonTarget.setAttribute(
      "aria-pressed",
      isStarred ? "true" : "false"
    );
    this.starButtonTarget.setAttribute(
      "title",
      isStarred ? "Remove from goals" : "Add to goals"
    );
  }
}
