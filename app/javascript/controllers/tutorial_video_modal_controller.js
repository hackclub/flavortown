import { Controller } from "@hotwired/stimulus";
import * as Turbo from "@hotwired/turbo";

export default class extends Controller {
  static targets = ["dialog", "iframe"];

  open(event) {
    event.preventDefault();
    this.currentCompleteUrl = event.params.completeUrl;
    this.completed = false;

    this.setupMessageListener();

    const videoUrl = event.params.videoUrl;
    if (videoUrl) {
      this.iframeTarget.onload = () => this.subscribeToVimeoEvents();
      this.iframeTarget.src = videoUrl;
    }

    this.dialogTarget.showModal();
  }

  close() {
    this.dialogTarget.close();
    this.stopVideo();
  }

  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) {
      this.close();
    }
  }

  setupMessageListener() {
    if (this.messageListenerSetup) return;

    this.messageListenerSetup = true;

    this.boundHandleVimeoMessage = this.handleVimeoMessage.bind(this);
    window.addEventListener("message", this.boundHandleVimeoMessage);
  }

  subscribeToVimeoEvents() {
    const player = this.iframeTarget.contentWindow;
    player.postMessage(
      JSON.stringify({ method: "addEventListener", value: "play" }),
      "*",
    );
  }

  disconnect() {
    if (this.boundHandleVimeoMessage) {
      window.removeEventListener("message", this.boundHandleVimeoMessage);
    }
  }

  handleVimeoMessage(event) {
    if (event.origin !== "https://player.vimeo.com") return;

    try {
      const data =
        typeof event.data === "string" ? JSON.parse(event.data) : event.data;
      if (data.event === "play") {
        this.markComplete();
      }
    } catch (e) {
      // Ignore non-JSON messages
    }
  }

  async markComplete() {
    if (this.completed || !this.currentCompleteUrl) return;

    this.completed = true;

    try {
      const response = await fetch(this.currentCompleteUrl, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
            ?.content,
          Accept: "text/vnd.turbo-stream.html",
        },
      });

      if (response.ok) {
        const html = await response.text();
        Turbo.renderStreamMessage(html);
      }
    } catch (error) {
      console.error("Failed to mark tutorial step complete:", error);
    }
  }

  stopVideo() {
    const iframe = this.iframeTarget;
    const player = iframe.contentWindow;
    player.postMessage(JSON.stringify({ method: "pause" }), "*");
  }
}
