import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["select", "selectedContainer", "hiddenInputs"];
  static values = { initialProjects: Array, projectTimes: Object };

  connect() {
    this.selectedProjects = new Set();
    // Seed initial selected projects if provided as values
    if (
      this.hasInitialProjectsValue &&
      Array.isArray(this.initialProjectsValue)
    ) {
      const seeds = this.initialProjectsValue;
      seeds.forEach(async (proj) => {
        const id = String(proj.id);
        const name = proj.name || `Project ${id}`;
        if (!this.selectedProjects.has(id)) {
          this.selectedProjects.add(id);
          await this.renderSelectedProject(id, name);
        }
      });
    }
    this.updateHiddenInputs();
  }

  async addProject(event) {
    const select = event.target;
    const selectedOption = select.options[select.selectedIndex];

    if (!selectedOption.value) return;

    const projectId = selectedOption.value;
    const projectName = selectedOption.dataset.name;

    if (this.selectedProjects.has(projectId)) {
      select.selectedIndex = 0;
      return;
    }

    this.selectedProjects.add(projectId);
    await this.renderSelectedProject(projectId, projectName);
    this.updateHiddenInputs();

    select.selectedIndex = 0;
  }

  removeProject(event) {
    const projectId = event.currentTarget.dataset.projectId;
    this.selectedProjects.delete(projectId);

    const projectElement = event.currentTarget.closest(
      ".hackatime-project-selector__project",
    );
    if (projectElement) {
      projectElement.remove();
    }

    this.updateHiddenInputs();
  }

  formatTime(totalSeconds) {
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    return `${hours}h ${minutes}m`;
  }

  async renderSelectedProject(projectId, projectName) {
    const projectIconPath =
      this.element.dataset.projectIconPath || "/assets/icons/rocket.svg";
    const closeIconPath =
      this.element.dataset.closeIconPath || "/assets/icons/close.svg";

    const rocketSvg = await this.loadSvgAsInline(projectIconPath, 24);
    const closeSvg = await this.loadSvgAsInline(closeIconPath, 20);

    const projectTimes = this.hasProjectTimesValue ? this.projectTimesValue : {};
    const totalSeconds = projectTimes[projectName] || 0;
    const timeDisplay = this.formatTime(totalSeconds);

    const projectElement = document.createElement("div");
    projectElement.className = "hackatime-project-selector__project";
    projectElement.innerHTML = `
      <div class="hackatime-project-selector__project-icon">
        ${rocketSvg}
      </div>
      <div class="hackatime-project-selector__project-content">
        <div class="hackatime-project-selector__project-name">${this.escapeHtml(projectName)}</div>
        <div class="hackatime-project-selector__project-meta">Time tracked: ${timeDisplay}</div>
      </div>
      <button 
        type="button"
        class="hackatime-project-selector__project-remove"
        data-action="click->hackatime-project-selector#removeProject"
        data-project-id="${projectId}"
        aria-label="Remove ${this.escapeHtml(projectName)}"
      >
        ${closeSvg}
      </button>
    `;

    this.selectedContainerTarget.appendChild(projectElement);
  }

  async loadSvgAsInline(path, size = 24) {
    try {
      const response = await fetch(path);
      const svgText = await response.text();
      const svgMatch = svgText.match(/<svg[^>]*>[\s\S]*<\/svg>/i);
      if (svgMatch) {
        let svg = svgMatch[0];
        svg = svg.replace(/fill="[^"]*"/g, 'fill="currentColor"');
        svg = svg.replace(/stroke="[^"]*"/g, 'stroke="currentColor"');
        if (!svg.includes("width=")) {
          svg = svg.replace("<svg", `<svg width="${size}" height="${size}"`);
        }
        return svg;
      }
    } catch (e) {
      console.warn("Failed to load SVG:", e);
    }
    return `<img src="${this.escapeHtml(path)}" alt="" width="${size}" height="${size}" />`;
  }

  updateHiddenInputs() {
    this.hiddenInputsTarget.innerHTML = "";

    const form = this.element.closest("form");
    if (!form) return;

    const formNameInput = form.querySelector(
      "input[name*='[title]'], input[name*='[id]']",
    );
    let formName = "project";
    if (formNameInput) {
      const match = formNameInput.name.match(/^([^\[]+)\[/);
      if (match) {
        formName = match[1];
      }
    }

    const attributeName =
      this.element.dataset.attribute || "hackatime_project_ids";

    this.selectedProjects.forEach((projectId) => {
      const input = document.createElement("input");
      input.type = "hidden";
      input.name = `${formName}[${attributeName}][]`;
      input.value = projectId;
      this.hiddenInputsTarget.appendChild(input);
    });
  }

  // Potential XSS cc:@toshit, @jmeow. That said, it should be relatively safe!
  escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }
}
