import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["dialog", "content", "button"];
  static values = { url: String };

  connect() {
    this.storageKey = "minequest_recent_ideas";
  }

  open(e) {
    e.preventDefault();
    this.dialogTarget.classList.remove("hidden");
  }

  close(e) {
    e.preventDefault();
    this.dialogTarget.classList.add("hidden");
  }

  async generate(e) {
    e.preventDefault();

    this.buttonTarget.disabled = true;
    this.buttonTarget.textContent = "Loading...";
    this.contentTarget.innerHTML = "<p>Generating a Cool Idea...</p>";

    const csrfToken = document.querySelector(
      'meta[name="csrf-token"]',
    )?.content;

    try {
      const idea = await this.fetchUniqueIdea(csrfToken);
      this.renderIdea(idea);
    } catch (err) {
      this.contentTarget.innerHTML = "<p>Failed to connect to the server.</p>";
    } finally {
      this.buttonTarget.disabled = false;
      this.buttonTarget.textContent = "Generate Idea";
    }
  }

  async fetchUniqueIdea(csrfToken) {
    const seenIdeas = this.loadSeenIdeas();
    const maxAttempts = 3;

    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
        },
        body: JSON.stringify({ exclude_ideas: seenIdeas }),
      });
      const data = await response.json();
      const normalized = this.normalizeIdea(data.idea);

      if (!normalized) {
        continue;
      }

      if (!seenIdeas.includes(normalized)) {
        this.storeSeenIdea(normalized);
        return data;
      }
    }

    return {
      idea: "You've seen a lot of ideas already. Try again in a bit for new inspiration.",
      difficulty: "Mixed",
      time_estimate: "Varies",
    };
  }

  renderIdea(data) {
    const parsed = this.coerceIdeaPayload(data);
    const ideaText = this.escapeHtml(parsed.idea || "No idea generated.");
    const difficulty = this.escapeHtml(parsed.difficulty || "Medium");
    const timeEstimate = this.escapeHtml(parsed.time_estimate || "2-4 hours");

    this.contentTarget.innerHTML = `
      <p>${ideaText}</p>
      <div class="minecraft-idea-tags">
        <span class="minecraft-idea-tag">Difficulty: ${difficulty}</span>
        <span class="minecraft-idea-tag">Time: ${timeEstimate}</span>
      </div>
    `;
  }

  loadSeenIdeas() {
    try {
      const saved = JSON.parse(localStorage.getItem(this.storageKey) || "[]");
      return Array.isArray(saved) ? saved : [];
    } catch (_e) {
      return [];
    }
  }

  storeSeenIdea(idea) {
    const seenIdeas = this.loadSeenIdeas();
    const updated = [
      idea,
      ...seenIdeas.filter((entry) => entry !== idea),
    ].slice(0, 20);
    localStorage.setItem(this.storageKey, JSON.stringify(updated));
  }

  normalizeIdea(idea) {
    return (idea || "")
      .toLowerCase()
      .replace(/[^a-z0-9 ]/g, "")
      .replace(/\s+/g, " ")
      .trim();
  }

  coerceIdeaPayload(data) {
    if (data && typeof data === "object") {
      const maybeJson = this.tryParseIdeaString(data.idea);
      if (maybeJson) {
        return {
          idea: maybeJson.idea || data.idea,
          difficulty: maybeJson.difficulty || data.difficulty,
          time_estimate: maybeJson.time_estimate || data.time_estimate,
        };
      }
      return data;
    }

    return {
      idea: "No idea generated.",
      difficulty: "Medium",
      time_estimate: "2-4 hours",
    };
  }

  tryParseIdeaString(idea) {
    if (typeof idea !== "string") return null;
    const text = idea.trim();
    const candidates = [text];

    const fencedMatch = text.match(/```(?:json)?\s*(\{.*?\})\s*```/ms);
    if (fencedMatch?.[1]) candidates.push(fencedMatch[1]);

    const inlineMatch = text.match(/\{[\s\S]*\}/m);
    if (inlineMatch?.[0]) candidates.push(inlineMatch[0]);

    for (const candidate of candidates) {
      try {
        const parsed = JSON.parse(candidate);
        if (parsed && typeof parsed === "object") return parsed;
      } catch (_e) {
        continue;
      }
    }

    return null;
  }

  escapeHtml(text) {
    return String(text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }
}
