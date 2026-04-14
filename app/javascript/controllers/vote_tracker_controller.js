import { Controller } from "@hotwired/stimulus";

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
      event.preventDefault();
      this.repoFieldTarget.value = "true";
      window.open(event.currentTarget.href, "_blank", "noopener,noreferrer");
      return;
    }
    this.repoFieldTarget.value = "true";
  }

  trackDemoClick(event) {
    if (event.type === "auxclick" && event.button === 2) {
      event.preventDefault();
      this.demoFieldTarget.value = "true";
      window.open(event.currentTarget.href, "_blank", "noopener,noreferrer");
      return;
    }
    this.demoFieldTarget.value = "true";
  }

  submit(event) {
    this.rmErr();

    const reasonField = this.formTarget.querySelector('[name="vote[reason]"]');
    if (reasonField) {
      const text = (reasonField.value ?? "").trim();
      const wordCount = text ? text.split(/\s+/).length : 0;
      if (wordCount < 10) {
        event.preventDefault();
        this.showErr();
        reasonField.focus();
        return;
      }
    }

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

  showErr() {
    const container = this.formTarget.querySelector(".vote-form__feedback");
    if (container) container.classList.add("vote-form__feedback--invalid");
  }

  rmErr() {
    const container = this.formTarget.querySelector(".vote-form__feedback");
    if (container) container.classList.remove("vote-form__feedback--invalid");
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
    if (this.hasExtremeModalTarget && !this.extremeModalTarget.open) {
      this.extremeModalTarget.showModal();
    }
  }

  closeExtremeModal() {
    if (this.hasExtremeModalTarget && this.extremeModalTarget.open) {
      this.extremeModalTarget.close();
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
