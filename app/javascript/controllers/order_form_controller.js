import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "input",
    "preview",
    "dropdown",
    "submitButton",
    "summaryQtyDisplay",
    "summaryTotalDisplay",
    "accessoriesListContainer",
    "accessoriesListItems",
  ];

  static values = {
    addresses: Array,
    hasAddresses: Boolean,
    baseTicketCost: Number,
    userBalance: Number,
  };

  connect() {
    if (this.hasSubmitButtonTarget) {
      this.initialGetButtonHTML = this.submitButtonTarget.innerHTML;
    }

    this.setupAccessoryRadioUndo();
    this.setupOrderSummary();
  }

  setupAccessoryRadioUndo() {
    const radios = this.element.querySelectorAll(
      ".shop-order__accessory-option-input",
    );
    radios.forEach((radio) => {
      radio.addEventListener("click", () => {
        if (radio.dataset.wasChecked === "true") {
          radio.checked = false;
          radio.dataset.wasChecked = "false";
          radio.dispatchEvent(new Event("change", { bubbles: true }));
        } else {
          this.element
            .querySelectorAll(`input[name="${radio.name}"]`)
            .forEach((r) => {
              r.dataset.wasChecked = "false";
            });
          radio.dataset.wasChecked = "true";
        }
      });
    });
  }

  setupOrderSummary() {
    this.quantityInput =
      this.element.querySelector("#shop-order__quantity-input") || null;

    this.accessoryCheckboxes = this.element.querySelectorAll(
      ".shop-order__accessory-checkbox",
    );
    this.accessoryRadios = this.element.querySelectorAll(
      ".shop-order__accessory-option-input",
    );

    if (this.quantityInput) {
      this.quantityInput.addEventListener("input", () =>
        this.updateOrderSummary(),
      );
    }

    this.accessoryCheckboxes.forEach((checkbox) => {
      checkbox.addEventListener("change", () => this.updateOrderSummary());
    });

    this.accessoryRadios.forEach((radio) => {
      radio.addEventListener("change", () => this.updateOrderSummary());
    });

    this.updateOrderSummary();
  }

  getSelectedAccessories() {
    const accessories = [];

    this.accessoryCheckboxes.forEach((checkbox) => {
      if (checkbox.checked) {
        const name = checkbox
          .closest("label")
          .querySelector(".shop-order__accessory-name").textContent;
        const price = parseFloat(checkbox.dataset.price) || 0;
        accessories.push({ name, price });
      }
    });

    this.accessoryRadios.forEach((radio) => {
      if (radio.checked) {
        const name = radio
          .closest("label")
          .querySelector(".shop-order__accessory-option-name").textContent;
        const price = parseFloat(radio.dataset.price) || 0;
        accessories.push({ name, price });
      }
    });

    return accessories;
  }

  updateOrderSummary() {
    const qty =
      parseInt(this.quantityInput ? this.quantityInput.value : 1, 10) || 1;
    const accessories = this.getSelectedAccessories();
    const accTotal = accessories.reduce((sum, acc) => sum + acc.price, 0);
    const total = this.baseTicketCostValue * qty + accTotal;

    if (
      this.hasAccessoriesListContainerTarget &&
      this.hasAccessoriesListItemsTarget
    ) {
      if (accessories.length > 0) {
        this.accessoriesListContainerTarget.style.display = "block";
        this.accessoriesListItemsTarget.innerHTML = accessories
          .map(
            (acc) =>
              `<li>${acc.name} <span>🍪 ${acc.price.toFixed(2)}</span></li>`,
          )
          .join("");
      } else {
        this.accessoriesListContainerTarget.style.display = "none";
        this.accessoriesListItemsTarget.innerHTML = "";
      }
    }

    if (this.hasSummaryQtyDisplayTarget) {
      this.summaryQtyDisplayTarget.textContent = `${qty}x`;
    }

    if (this.hasSummaryTotalDisplayTarget) {
      this.summaryTotalDisplayTarget.textContent = `🍪 ${total.toFixed(2)}`;
    }

    if (this.hasSubmitButtonTarget) {
      const canAfford = this.userBalanceValue >= total;
      const shortfall = Math.max(0, total - this.userBalanceValue);

      if (canAfford && this.hasAddressesValue) {
        this.submitButtonTarget.disabled = false;
        this.submitButtonTarget.innerHTML = this.initialGetButtonHTML;
      } else if (!canAfford) {
        this.submitButtonTarget.disabled = true;
        this.submitButtonTarget.innerHTML = `You need 🍪 ${shortfall.toFixed(0)} more cookies!`;
      } else {
        this.submitButtonTarget.disabled = true;
        this.submitButtonTarget.innerHTML = this.initialGetButtonHTML;
      }
    }
  }
}
