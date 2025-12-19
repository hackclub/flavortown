import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "dropdown", "option", "hiddenField"];
  static values = { open: Boolean };

  connect() {
    this.openValue = false;
    document.addEventListener("click", this.handleClickOutside.bind(this));
  }

  disconnect() {
    document.removeEventListener("click", this.handleClickOutside.bind(this));
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close();
    }
  }

  toggle() {
    this.openValue = !this.openValue;
  }

  open() {
    this.openValue = true;
    this.inputTarget.focus();
  }

  close() {
    this.openValue = false;
  }

  openValueChanged() {
    if (this.openValue) {
      this.dropdownTarget.style.display = "block";
    } else {
      this.dropdownTarget.style.display = "none";
    }
  }

  filter() {
    const query = this.inputTarget.value.toLowerCase();

    this.optionTargets.forEach((option) => {
      const searchText =
        option.dataset.searchText || option.textContent.toLowerCase();
      if (searchText.includes(query)) {
        option.style.display = "flex";
      } else {
        option.style.display = "none";
      }
    });
  }

  select(event) {
    const value = event.currentTarget.dataset.value;
    const label = event.currentTarget.dataset.label;

    this.hiddenFieldTarget.value = value;
    this.inputTarget.value = label;
    this.close();
  }

  selectAndSubmit(event) {
    const value = event.currentTarget.dataset.value;
    const label = event.currentTarget.dataset.label;

    this.hiddenFieldTarget.value = value;
    this.inputTarget.value = label;
    this.close();

    const form = this.element.querySelector("form");
    if (form) {
      form.submit();
    }
  }

  clear() {
    this.hiddenFieldTarget.value = "";
    this.inputTarget.value = "";
    this.filter();
  }
}
