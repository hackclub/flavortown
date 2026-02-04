import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["video", "select", "preview"];

  connect() {
    this.updatePreview();
    this.selectTarget?.addEventListener("change", () => this.selectTimelapse());
  }

  selectTimelapse() {
    this.updatePreview();
  }

  updatePreview() {
    if (!this.hasSelectTarget || !this.hasVideoTarget)
      return;

    const selectedOption = this.selectTarget.options[this.selectTarget.selectedIndex];
    const playbackUrl = selectedOption?.dataset?.playbackUrl;
    const thumbnailUrl = selectedOption?.dataset?.thumbnailUrl;

    if (playbackUrl) {
      this.videoTarget.src = playbackUrl;
      this.videoTarget.poster = thumbnailUrl || "";
      this.videoTarget.load();
      this.videoTarget.play().catch(() => {});
      this.previewTarget.classList.add("projects-new__lapse-preview--has-video");
    }
    else {
      this.videoTarget.src = "";
      this.videoTarget.poster = "";
      this.previewTarget.classList.remove("projects-new__lapse-preview--has-video",);
    }
  }
}
