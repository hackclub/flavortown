import { Controller } from "@hotwired/stimulus";
import { closeDialog, openDialog } from "./modal_controller";

export default class extends Controller {
  static targets = [
    "form",
    "timeField",
    "repoField",
    "demoField",
    "panel",
    "scrollArea",
    "toggleButton",
    "extremeModal",
  ];

  connect() {
    this.startTime = Date.now();
    this.isPanelOpen = false;
    this.extremeConfirmed = false;
    this.updatePanelState(false);

    this.boundPanelWheel = this.handlePanelWheel.bind(this);
    if (this.hasPanelTarget) {
      this.panelTarget.addEventListener("wheel", this.boundPanelWheel, {
        passive: false,
      });
    }
  }

  disconnect() {
    if (this.hasPanelTarget && this.boundPanelWheel) {
      this.panelTarget.removeEventListener("wheel", this.boundPanelWheel);
    }
  }

  trackRepoClick(event) {
    if (event.type === "auxclick" && event.button === 2) {
      return;
    }
    this.repoFieldTarget.value = "true";
  }

  trackDemoClick(event) {
    if (event.type === "auxclick" && event.button === 2) {
      return;
    }
    this.demoFieldTarget.value = "true";
  }

  submit(event) {
    const endTime = Date.now();
    const durationInSeconds = Math.max(
      1,
      Math.round((endTime - this.startTime) / 1000),
    );
    console.log(
      `Submitting vote. Time: ${durationInSeconds}s, Repo: ${this.repoFieldTarget.value}, Demo: ${this.demoFieldTarget.value}`,
    );
    this.timeFieldTarget.value = durationInSeconds;

    if (!this.extremeConfirmed && this.hasExtremeScore()) {
      event.preventDefault();
      this.openExtremeModal();
      return;
    }

    this.extremeConfirmed = false;
  }

  confirmExtreme() {
    this.extremeConfirmed = true;
    this.closeExtremeModal();
    this.formTarget.requestSubmit();
  }

  togglePanel() {
    this.updatePanelState(!this.isPanelOpen);
  }

  closePanel() {
    if (!this.isPanelOpen) {
      return;
    }

    this.updatePanelState(false);
  }

  updatePanelState(open) {
    if (!this.hasPanelTarget) {
      return;
    }

    this.isPanelOpen = open;
    this.panelTarget.classList.toggle("is-open", open);
    this.panelTarget.setAttribute("aria-hidden", (!open).toString());

    if (this.hasToggleButtonTarget) {
      this.toggleButtonTarget.setAttribute("aria-expanded", open.toString());
    }
  }

  hasExtremeScore() {
    const checkedInputs = this.formTarget.querySelectorAll(
      ".vote-category__input:checked",
    );
    return Array.from(checkedInputs).some((input) =>
      ["1", "9"].includes(input.value),
    );
  }

  openExtremeModal() {
    if (this.hasExtremeModalTarget) {
      openDialog(this.extremeModalTarget);
    }
  }

  closeExtremeModal() {
    if (this.hasExtremeModalTarget) {
      closeDialog(this.extremeModalTarget);
    }
  }

  handlePanelWheel(event) {
    if (!this.isPanelOpen || !this.hasScrollAreaTarget) {
      return;
    }

    if (this.hasExtremeModalTarget && this.extremeModalTarget.open) {
      return;
    }

    const scrollArea = this.scrollAreaTarget;
    const { scrollHeight, clientHeight } = scrollArea;
    if (scrollHeight <= clientHeight) {
      event.preventDefault();
      return;
    }

    event.preventDefault();
    scrollArea.scrollTop += event.deltaY;
  }
}
