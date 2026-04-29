import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["tab", "panel"];

  connect() {
    this.showTab(0);
  }

  switch(event) {
    event.preventDefault();
    const index = this.tabTargets.indexOf(event.currentTarget);
    this.showTab(index);
  }

  showTab(index) {
    this.tabTargets.forEach((tab, i) => {
      tab.classList.toggle("active", i === index);
    });
    this.panelTargets.forEach((panel, i) => {
      panel.classList.toggle("hidden", i !== index);
    });
  }
}
