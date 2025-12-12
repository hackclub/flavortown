import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { projectId: Number };

  async mark(event) {
    event.preventDefault();

    const projectId = this.projectIdValue;
    if (!projectId) return;

    const token = document
      .querySelector('meta[name="csrf-token"]')
      ?.getAttribute("content");

    try {
      const resp = await fetch(`/projects/${projectId}/mark_fire`, {
        method: "POST",
        headers: {
          Accept: "application/json",
          ...(token ? { "X-CSRF-Token": token } : {}),
        },
      });

      const raw = await resp.text();
      let payload = {};
      try {
        payload = JSON.parse(raw);
      } catch {
        payload = { message: raw };
      }

      if (!resp.ok) {
        console.error("mark_fire failed", resp.status, payload);
        alert(payload.message || `Failed (${resp.status})`);
        return;
      }

      alert(payload.message || "Marked as 🔥");
      window.location.reload();
    } catch (e) {
      console.error(e);
      alert("Request failed");
    }
  }
}
