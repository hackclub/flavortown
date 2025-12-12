import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { projectId: Number, isFire: Boolean };

  async toggle(event) {
    event.preventDefault();

    const projectId = this.projectIdValue;
    if (!projectId) return;

    const endpoint = this.isFireValue ? "unmark_fire" : "mark_fire";

    const token = document
      .querySelector('meta[name="csrf-token"]')
      ?.getAttribute("content");

    try {
      const resp = await fetch(`/projects/${projectId}/${endpoint}`, {
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
        console.error(`${endpoint} failed`, resp.status, payload);
        alert(payload.message || `Failed (${resp.status})`);
        return;
      }

      alert(
        payload.message || (this.isFireValue ? "Unmarked 🔥" : "Marked as 🔥"),
      );
      window.location.reload();
    } catch (e) {
      console.error(e);
      alert("Request failed");
    }
  }
}
