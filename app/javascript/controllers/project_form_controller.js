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
    "updateDescriptionContainer",
    "updateDescriptionField",
  ];

  static values = {
    updatePrefix: { type: String, default: "Updated Project:" },
  };

  connect() {
    this.userEditedReadme = false;
    this.submitting = false;
    this.debouncedDetect = this.debounce(() => this.detectReadme(), 400);

    // Store the base description (without prefixes)
    this.baseDescription = "";

    // Reset submitting flag after direct uploads complete so the form can
    // be re-submitted with the signed blob ID by Active Storage.
    this.element.addEventListener("direct-upload:end", () => {
      this.submitting = false;
    });
    this.element.addEventListener("direct-upload:error", () => {
      this.submitting = false;
      if (this.hasSubmitTarget) this.submitTarget.disabled = false;
    });

    if (this.hasReadmeUrlTarget) {
      this.readmeUrlTarget.addEventListener("input", () => {
        this.userEditedReadme = true;
        this.readmeUrlTarget.removeAttribute("data-autofilled");
      });
    }

    this.updateSubmitState(); // submit button

    this.restorReadmeWhenThereIsAError();

    // Initialize base description from current value (strip prefixes if present)
    this.initializeBaseDescription();

    // Sync checkbox state on load if description already has prefix
    this.syncUpdateCheckbox();

    // Sync update description visibility on load
    this.syncUpdateDescriptionVisibility();

    if (
      this.hasRepoUrlTarget &&
      this.hasReadmeUrlTarget &&
      !this.readmeUrlTarget.value
    ) {
      setTimeout(() => this.detectReadme(), 0);
    }
  }

  initializeBaseDescription() {
    if (!this.hasDescriptionTarget) return;

    let description = this.descriptionTarget.value.trimStart();
    const updatePrefix = this.updatePrefixValue;

    // Strip any existing prefix to get the base description
    if (description.startsWith(updatePrefix)) {
      const afterPrefix = description.substring(updatePrefix.length).trimStart();
      // Find where the update description ends (look for double space)
      const doubleSpaceIndex = afterPrefix.indexOf("  ");
      if (doubleSpaceIndex !== -1) {
        this.baseDescription = afterPrefix.substring(doubleSpaceIndex).trimStart();
      } else {
        this.baseDescription = "";
      }
    } else {
      this.baseDescription = description;
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

  onDescriptionInput(event) {
    this.updateBaseDescription();
    this.validateDescription(event);
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

  // Track changes to the base description (when user types in the description field)
  updateBaseDescription() {
    if (!this.hasDescriptionTarget) return;

    const currentValue = this.descriptionTarget.value.trimStart();
    const updatePrefix = this.updatePrefixValue;

    // Extract the base description from the current value
    if (currentValue.startsWith(updatePrefix)) {
      const afterPrefix = currentValue.substring(updatePrefix.length).trimStart();
      const doubleSpaceIndex = afterPrefix.indexOf("  ");
      if (doubleSpaceIndex !== -1) {
        this.baseDescription = afterPrefix.substring(doubleSpaceIndex).trimStart();
      } else {
        // User might be editing, so be conservative
        this.baseDescription = afterPrefix;
      }
    } else {
      this.baseDescription = currentValue;
    }
  }

  validateUpdateDescription(event) {
    if (!this.hasUpdateDescriptionFieldTarget) return;
    const el = this.updateDescriptionFieldTarget;
    const value = (el.value || "").trim();
    let message = "";

    // Only require if the update checkbox is checked
    if (this.hasUpdateDeclarationTarget && this.updateDeclarationTarget.checked) {
      if (!value) {
        message = "Update description is required when marking as an update";
      } else if (value.length > 200) {
        message = "Update description must be 200 characters or fewer";
      }
    }

    el.setCustomValidity(message);
    if (event?.type === "blur") {
      el.reportValidity();
      if (message) this.triggerShake(el);
    }
    this.updateSubmitState();
  }

  onUpdateDescriptionInput(event) {
    this.validateUpdateDescription(event);
    this.rebuildPrefixes();
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
      return;
    }

    if (this.submitting) {
      event.preventDefault();
      return;
    }
    this.submitting = true;

    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true;
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
    this.syncUpdateDescriptionVisibility();
    this.rebuildPrefixes();
  }

  syncUpdateCheckbox() {
    if (!this.hasDescriptionTarget || !this.hasUpdateDeclarationTarget) return;

    const prefix = this.updatePrefixValue;
    const hasPrefix = this.descriptionTarget.value.trimStart().includes(prefix);
    this.updateDeclarationTarget.checked = hasPrefix;
  }

  syncUpdateDescriptionVisibility() {
    if (!this.hasUpdateDescriptionContainerTarget) return;

    const isChecked = this.hasUpdateDeclarationTarget && this.updateDeclarationTarget.checked;
    this.updateDescriptionContainerTarget.hidden = !isChecked;

    if (!isChecked && this.hasUpdateDescriptionFieldTarget) {
      // Clear the field and validation when hiding
      this.updateDescriptionFieldTarget.value = "";
      this.updateDescriptionFieldTarget.setCustomValidity("");
    } else if (isChecked && this.hasUpdateDescriptionFieldTarget) {
      // Validate when showing
      this.validateUpdateDescription();
    }
  }

  // Rebuild prefixes based on checkbox states
  rebuildPrefixes() {
    if (!this.hasDescriptionTarget) return;

    const updatePrefix = this.updatePrefixValue;

    // Build new prefix based on checkbox states
    const prefixes = [];
    if (
      this.hasUpdateDeclarationTarget &&
      this.updateDeclarationTarget.checked
    ) {
      const updateDesc = this.hasUpdateDescriptionFieldTarget
        ? (this.updateDescriptionFieldTarget.value || "").trim()
        : "";

      if (updateDesc) {
        prefixes.push(`${updatePrefix} ${updateDesc}`);
      } else {
        prefixes.push(updatePrefix);
      }
    }

    // Use baseDescription (the original description without prefixes)
    const combinedPrefix = prefixes.length > 0 ? `${prefixes.join(", ")}  ` : "";
    this.descriptionTarget.value = combinedPrefix + this.baseDescription;

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
