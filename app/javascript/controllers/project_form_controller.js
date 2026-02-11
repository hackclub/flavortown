import { Controller } from "@hotwired/stimulus";

// data-controller="project-form"
export default class extends Controller {
  static targets = [
    "title",
    "description",
    "demoUrl",
    "repoUrl",
    "readmeUrl",
    "readmeContainer",
    "submit",
    "updateDeclaration",
  ];

  static values = {
    updatePrefix: { type: String, default: "Updated Project:" },
  };

  connect() {
    this.userEditedReadme = false;
    this.debouncedDetect = this.debounce(() => this.detectReadme(), 400);

    if (this.hasReadmeUrlTarget) {
      this.readmeUrlTarget.addEventListener("input", () => {
        this.userEditedReadme = true;
        this.readmeUrlTarget.removeAttribute("data-autofilled");
      });
    }

    this.updateSubmitState(); // submit button

    this.restorReadmeWhenThereIsAError();

    // Sync checkbox state on load if description already has prefix
    this.syncUpdateCheckbox();

    if (
      this.hasRepoUrlTarget &&
      this.hasReadmeUrlTarget &&
      !this.readmeUrlTarget.value
    ) {
      setTimeout(() => this.detectReadme(), 0);
    }
  }

  // Validation handlers
  validateTitle(event) {
    if (!this.hasTitleTarget) return;
    const el = this.titleTarget;
    const value = (el.value || "").trim();
    let message = "";
    if (!value) {
      message = "Title is required";
    } else if (value.length > 120) {
      message = "Title must be 120 characters or fewer";
    }
    el.setCustomValidity(message);
    if (event?.type === "blur") {
      el.reportValidity();
      if (message) this.triggerShake(el);
    }
    this.updateSubmitState();
  }

  validateDescription(event) {
    if (!this.hasDescriptionTarget) return;
    const el = this.descriptionTarget;
    const value = el.value || "";
    let message = "";
    if (value.length > 1000) {
      message = "Description must be 1000 characters or fewer";
    }
    el.setCustomValidity(message);
    if (event?.type === "blur") {
      el.reportValidity();
      if (message) this.triggerShake(el);
    }
    this.updateSubmitState();
  }

  validateUrl(event) {
    const el = event?.target || null;
    if (!el) return;
    const value = (el.value || "").trim();
    let message = "";
    if (value.length > 0) {
      try {
        const url = new URL(value);
        if (!["http:", "https:"].includes(url.protocol)) {
          message = "URL must start with http or https";
        } else if (value.length > 2048) {
          message = "URL is too long";
        }
      } catch {
        message = "Enter a valid URL";
      }
    }
    el.setCustomValidity(message);
    if (event?.type === "blur") {
      el.reportValidity();
      if (message) this.triggerShake(el);
    }
    this.updateSubmitState();
  }

  // input change -> validate + detect (try)
  onRepoInput(event) {
    this.validateUrl(event);
    this.debouncedDetect();
  }

  onRepoBlur(event) {
    this.validateUrl(event);
    this.detectReadme();
  }

  onReadmeInput(event) {
    this.userEditedReadme = true;
    this.readmeUrlTarget.removeAttribute("data-autofilled");
    this.validateUrl(event);
  }

  updateSubmitState() {
    if (!this.hasSubmitTarget) return;
    this.submitTarget.disabled = false;
  }

  onSubmit(event) {
    const form = this.element.closest("form") || this.element;
    if (!form.checkValidity()) {
      form.reportValidity();
      event.preventDefault();
      // shake all invalid inputs
      const invalid = form.querySelectorAll(
        "input:invalid, textarea:invalid, select:invalid",
      );
      invalid.forEach((field) => this.triggerShake(field));
    }
  }

  // README detection
  async detectReadme() {
    if (!this.hasRepoUrlTarget || !this.hasReadmeUrlTarget) return;

    // Do not override if user manually edited
    if (this.userEditedReadme && !this.readmeUrlTarget.dataset.autofilled) {
      return;
    }

    const repoValue = (this.repoUrlTarget.value || "").trim();
    if (!repoValue) {
      return;
    }

    let url;
    try {
      url = new URL(repoValue);
    } catch {
      this.revealReadme(); // if what user enters is not a URL
      return;
    }

    const host = url.host.toLowerCase();
    const [_, owner, rawRepo] = (url.pathname || "").split("/");
    if (!owner || !rawRepo) {
      this.revealReadme();
      return;
    }
    const repo = rawRepo.replace(/\.git$/i, "");

    let readmeUrl = null;
    try {
      if (host === "github.com") {
        readmeUrl = await this.findGithubReadme(owner, repo);
      } else if (host === "gitlab.com") {
        readmeUrl = await this.findGitlabReadme(owner, repo);
      } else {
        // unsupported remote
        this.revealReadme();
        return;
      }
    } catch {
      this.revealReadme();
      return;
    }
    if (readmeUrl) {
      if (
        !this.readmeUrlTarget.value ||
        this.readmeUrlTarget.dataset.autofilled
      ) {
        this.readmeUrlTarget.value = readmeUrl;
        this.readmeUrlTarget.dataset.autofilled = "true";
        this.userEditedReadme = false;
        // unhide but disable the input (autofilled)
        if (this.hasReadmeContainerTarget)
          this.readmeContainerTarget.hidden = false;
        this.readmeUrlTarget.readOnly = true;
        // add visual lock state
        const control = this.readmeUrlTarget.closest(".input__control");
        if (control) control.classList.add("input__control--locked");
        this.readmeUrlTarget.title = "Autodetected from repository (locked)";
        this.validateUrl({ target: this.readmeUrlTarget });
      }
    } else {
      this.revealReadme();
    }
  }

  async findGithubReadme(owner, repo) {
    const api = `https://api.github.com/repos/${owner}/${repo}/readme`;
    try {
      const res = await fetch(api, {
        headers: { Accept: "application/vnd.github.v3+json" },
        cache: "no-store",
      });
      if (res.ok) {
        const json = await res.json();
        if (json && json.download_url) return json.download_url;
      }
    } catch {}
    // we are intentionally avoiding pattern matchign
    return null;
  }

  async findGitlabReadme(owner, repo) {
    const project = encodeURIComponent(`${owner}/${repo}`);
    const api = `https://gitlab.com/api/v4/projects/${project}/repository/files/README.md?ref=HEAD`;
    try {
      const res = await fetch(api, { cache: "no-store" });
      if (res.ok) {
        return `https://gitlab.com/${owner}/${repo}/-/raw/HEAD/README.md`;
      }
    } catch {}
    // we are intentionally avoiding pattern matchign
    return null;
  }

  revealReadme() {
    if (this.hasReadmeContainerTarget)
      this.readmeContainerTarget.hidden = false;
    // succesfully reveal, but should look visually different!
    if (this.hasReadmeUrlTarget) {
      this.readmeUrlTarget.readOnly = false;
      const control = this.readmeUrlTarget.closest(".input__control");
      if (control) control.classList.remove("input__control--locked");
      this.readmeUrlTarget.removeAttribute("title");
    }
  }

  restorReadmeWhenThereIsAError() {
    if (!this.hasReadmeContainerTarget || !this.hasReadmeUrlTarget) return;
    const value = (this.readmeUrlTarget.value || "").trim();
    if (!value) return;

    this.readmeContainerTarget.hidden = false;

    if (this.readmeUrlTarget.dataset.autofilled === "true") {
      this.readmeUrlTarget.readOnly = true;
      const control = this.readmeUrlTarget.closest(".input__control");
      if (control) control.classList.add("input__control--locked");
      this.readmeUrlTarget.title = "Autodetected from repository (locked)";
      this.userEditedReadme = false;
    } else {
      this.readmeUrlTarget.readOnly = false;
      const control = this.readmeUrlTarget.closest(".input__control");
      if (control) control.classList.remove("input__control--locked");
      this.readmeUrlTarget.removeAttribute("title");
      this.userEditedReadme = true;
    }
  }

  // Update Declaration checkbox handlers
  toggleUpdatePrefix() {
    this.rebuildPrefixes();
  }

  syncUpdateCheckbox() {
    if (!this.hasDescriptionTarget || !this.hasUpdateDeclarationTarget) return;

    const prefix = this.updatePrefixValue;
    const hasPrefix = this.descriptionTarget.value.trimStart().includes(prefix);
    this.updateDeclarationTarget.checked = hasPrefix;
  }

  // Rebuild prefixes based on checkbox states
  rebuildPrefixes() {
    if (!this.hasDescriptionTarget) return;

    // Strip all existing prefixes from description
    let description = this.descriptionTarget.value.trimStart();
    const updatePrefix = this.updatePrefixValue;

    // Remove update prefix (with optional trailing comma/space)
    const prefixPattern = new RegExp(
      `^${this.escapeRegex(updatePrefix)}(,\\s*|\\s+)`,
      "g",
    );
    // Keep removing prefixes until none remain
    let prevDescription;
    do {
      prevDescription = description;
      description = description.replace(prefixPattern, "").trimStart();
    } while (description !== prevDescription);

    // Build new prefix based on checkbox states
    const prefixes = [];
    if (
      this.hasUpdateDeclarationTarget &&
      this.updateDeclarationTarget.checked
    ) {
      prefixes.push(updatePrefix);
    }
    const combinedPrefix = prefixes.length > 0 ? `${prefixes.join(", ")} ` : "";
    this.descriptionTarget.value = combinedPrefix + description;

    this.validateDescription();
  }

  escapeRegex(string) {
    return string.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  }

  // util
  debounce(fn, wait) {
    let t;
    return (...args) => {
      clearTimeout(t);
      t = setTimeout(() => fn.apply(this, args), wait);
    };
  }

  triggerShake(field) {
    const wrapper = field.closest(".input");
    if (!wrapper) return;
    // restart animation by toggling the class
    wrapper.classList.remove("input--shake");
    // force reflow
    // eslint-disable-next-line no-unused-expressions
    wrapper.offsetWidth;
    wrapper.classList.add("input--shake");
    // auto-remove after animation ends as a fallback
    setTimeout(() => wrapper.classList.remove("input--shake"), 400);
  }
}
