import { Controller } from "@hotwired/stimulus";

export function openDialog(dialog) {
  if (!dialog || dialog.tagName !== "DIALOG") return;
  if (!dialog.open) {
    dialog.showModal();
  }
  document.body.style.overflow = "hidden";
}

export function closeDialog(dialog) {
  if (!dialog || dialog.tagName !== "DIALOG") return;
  if (dialog.open) {
    dialog.close();
  }
  document.body.style.overflow = "";
}

export default class extends Controller {
  static values = { target: String };

  connect() {
    this._boundBackdropClick = this.backdropClick.bind(this);

    if (!this.hasTargetValue) {
      this.element.addEventListener("click", this._boundBackdropClick);
    }

    this.openSettingsModalFromQueryParam();
  }

  disconnect() {
    if (!this.hasTargetValue) {
      this.element.removeEventListener("click", this._boundBackdropClick);
    }
  }

  open() {
    const modal = document.getElementById(this.targetValue);
    openDialog(modal);
  }

  close() {
    if (this.element.tagName === "DIALOG") {
      closeDialog(this.element);
      return;
    }

    if (this.hasTargetValue) {
      const modal = document.getElementById(this.targetValue);
      closeDialog(modal);
      return;
    }
  }

  backdropClick(event) {
    if (this.element.tagName !== "DIALOG") return;

    const rect = this.element.getBoundingClientRect();
    const clickedInside =
      event.clientX >= rect.left &&
      event.clientX <= rect.right &&
      event.clientY >= rect.top &&
      event.clientY <= rect.bottom;

    if (!clickedInside) this.close();
  }

  openSettingsModalFromQueryParam() {
    if (this.element.id !== "settings-modal") return;

    const params = new URLSearchParams(window.location.search);
    const settingsParam = params.get("settings");
    if (!["1", "true"].includes(settingsParam)) return;

    openDialog(this.element);

    params.delete("settings");
    const query = params.toString();
    const nextUrl = `${window.location.pathname}${query ? `?${query}` : ""}${
      window.location.hash
    }`;
    window.history.replaceState(window.history.state, "", nextUrl);
  }
}
