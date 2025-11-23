import { Controller } from "@hotwired/stimulus";

const DROPZONE_ACTIVE_CLASS = "file-upload__dropzone--active";
const DROPZONE_FILLED_CLASS = "file-upload__dropzone--filled";

export default class extends Controller {
  #processing = false;
  #previews = [];
  #currentIndex = 0;

  static targets = [
    "input",
    "dropzone",
    "placeholder",
    "preview",
    "filename",
    "progress",
    "progressBar",
    "status",
    "prevButton",
    "nextButton",
    "indicators",
    "addMore",
  ];
  static values = {
    maxSize: Number,
    initialUrl: String,
    initialFilename: String,
    initialPreviews: Array,
    maxCount: Number,
  };

  connect() {
    this.#reset();
    // multiple
    if (
      this.hasInitialPreviewsValue &&
      Array.isArray(this.initialPreviewsValue) &&
      this.initialPreviewsValue.length > 0
    ) {
      this.#previews = this.initialPreviewsValue.map((p) => ({
        url: p.url || null,
        filename: p.filename || "File",
      }));
      this.#currentIndex = 0;
      this.#renderCurrentPreview();
      if (this.inputTarget?.multiple && this.hasAddMoreTarget)
        this.addMoreTarget.hidden = false;
    } else if (this.hasInitialUrlValue && this.initialUrlValue) {
      this.#showPreviewFromUrl(
        this.initialUrlValue,
        this.hasInitialFilenameValue && this.initialFilenameValue
          ? this.initialFilenameValue
          : "Current file",
      );
    }
  }

  open(event) {
    event.preventDefault();
    this.inputTarget.click();
  }

  openWithKeyboard(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      this.inputTarget.click();
    }
  }

  dragOver(event) {
    event.preventDefault();
    if (this.hasDropzoneTarget)
      this.dropzoneTarget.classList.add(DROPZONE_ACTIVE_CLASS);
  }

  dragLeave(event) {
    event.preventDefault();
    if (this.hasDropzoneTarget)
      this.dropzoneTarget.classList.remove(DROPZONE_ACTIVE_CLASS);
  }

  drop(event) {
    event.preventDefault();
    if (this.hasDropzoneTarget)
      this.dropzoneTarget.classList.remove(DROPZONE_ACTIVE_CLASS);
    this.#processFiles(event.dataTransfer?.files);
  }

  handleSelection(event) {
    if (this.#processing) return;
    this.#processFiles(event.target.files);
  }

  uploadInitialize(event) {
    const { file } = event.detail;
    if (!this.#validateFileSize(file)) {
      event.preventDefault();
      this.#rejectFile(file);
      return;
    }
    // For single selection, keep existing behavior of previewing during upload.
    // For multiple selection, previews are rendered from the selection list.
    if (!this.inputTarget.multiple) {
      this.#showPreview(file);
    }
    this.#showProgress(0);
    this.#showStatus("Preparing upload…");
  }

  uploadStart(event) {
    this.#showProgress(0);
    this.#showStatus(`Uploading ${event.detail.file.name}…`);
  }

  uploadProgress(event) {
    this.#showProgress(event.detail.progress);
  }

  uploadError(event) {
    event.preventDefault();
    this.#hideProgress();
    this.#showStatus(event.detail.error, "error");
  }

  uploadEnd() {
    this.#showProgress(100);
    this.#showStatus("Upload complete", "success");
    setTimeout(() => {
      this.#hideProgress();
      this.#clearStatus();
    }, 1200);
  }

  #processFiles(fileList) {
    const files = Array.from(fileList || []);
    if (files.length === 0) return;

    const accepted = [];
    const rejected = [];
    for (const file of files) {
      if (this.#validateFileSize(file)) {
        accepted.push(file);
      } else {
        rejected.push(file);
      }
    }
    if (!this.inputTarget.multiple && accepted.length > 1) {
      accepted.splice(1);
    }
    // Enforce max count relative to existing files when in multiple mode
    if (
      this.inputTarget.multiple &&
      this.hasMaxCountValue &&
      this.maxCountValue
    ) {
      const existingCount =
        (this.inputTarget.files && this.inputTarget.files.length) || 0;
      const remaining = Math.max(0, this.maxCountValue - existingCount);
      if (accepted.length > remaining) {
        accepted.splice(remaining);
        const overBy = files.length - remaining;
        if (overBy > 0) {
          this.#showStatus(
            `You can upload up to ${this.maxCountValue} files total. ${remaining} more allowed.`,
            "error",
          );
        }
      }
    }

    if (accepted.length === 0) {
      if (rejected.length > 0) this.#rejectFile(rejected[0]);
      return;
    }

    this.#processing = true;
    try {
      const dt = new DataTransfer();
      // When multiple, merge existing files with newly accepted files
      const existing = this.inputTarget.multiple
        ? Array.from(this.inputTarget.files || [])
        : [];
      [...existing, ...accepted].forEach((f) => dt.items.add(f));
      this.inputTarget.files = dt.files;

      this.#filesToPreviewEntries(accepted).then((entries) => {
        if (this.inputTarget.multiple) {
          this.#previews = [...this.#previews, ...entries];
          // Jump to first of the newly added group
          this.#currentIndex = Math.max(
            0,
            this.#previews.length - entries.length,
          );
          if (this.hasAddMoreTarget) this.addMoreTarget.hidden = false;
        } else {
          this.#previews = entries;
          this.#currentIndex = 0;
        }
        this.#renderCurrentPreview();
      });
      this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }));
    } finally {
      this.#processing = false;
    }
  }

  prev(event) {
    event?.preventDefault?.();
    event?.stopPropagation?.();
    if (this.#previews.length <= 1) return;
    this.#currentIndex =
      (this.#currentIndex - 1 + this.#previews.length) % this.#previews.length;
    this.#renderCurrentPreview();
  }

  next(event) {
    event?.preventDefault?.();
    event?.stopPropagation?.();
    if (this.#previews.length <= 1) return;
    this.#currentIndex = (this.#currentIndex + 1) % this.#previews.length;
    this.#renderCurrentPreview();
  }

  goTo(event) {
    event?.preventDefault?.();
    event?.stopPropagation?.();
    const index = Number(event?.currentTarget?.dataset?.index ?? -1);
    if (Number.isNaN(index) || index < 0 || index >= this.#previews.length)
      return;
    this.#currentIndex = index;
    this.#renderCurrentPreview();
  }

  #showPreview(file) {
    if (!this.hasPreviewTarget) return;

    if (file.type.startsWith("image/")) {
      const reader = new FileReader();
      reader.onload = () => {
        this.previewTarget.innerHTML = `<img src="${reader.result}" alt="${file.name}" class="file-upload__preview-image" />`;
        this.#displayPreviewShell(file.name);
      };
      reader.readAsDataURL(file);
    } else {
      this.previewTarget.innerHTML = `<div class="file-upload__preview-fallback">${file.name}</div>`;
      this.#displayPreviewShell(file.name);
    }
  }

  #showPreviewFromUrl(url, filename = "Current file") {
    if (!this.hasPreviewTarget) return;
    this.previewTarget.innerHTML = `<img src="${url}" alt="${filename}" class="file-upload__preview-image" />`;
    this.#displayPreviewShell(filename);
  }

  async #filesToPreviewEntries(files) {
    return await Promise.all(
      files.map(
        (file) =>
          new Promise((resolve) => {
            if (file.type.startsWith("image/")) {
              const reader = new FileReader();
              reader.onload = () =>
                resolve({ url: reader.result, filename: file.name });
              reader.readAsDataURL(file);
            } else {
              resolve({ url: null, filename: file.name });
            }
          }),
      ),
    );
  }

  #renderCurrentPreview() {
    if (!this.hasPreviewTarget || this.#previews.length === 0) return;
    const current = this.#previews[this.#currentIndex];
    if (current.url) {
      this.previewTarget.innerHTML = `<img src="${current.url}" alt="${current.filename}" class="file-upload__preview-image" />`;
    } else {
      this.previewTarget.innerHTML = `<div class="file-upload__preview-fallback">${current.filename}</div>`;
    }
    this.#displayPreviewShell(current.filename);
    this.#updateCarouselUi();
  }

  #updateCarouselUi() {
    const many = this.#previews.length > 1;
    if (this.hasPrevButtonTarget) this.prevButtonTarget.hidden = !many;
    if (this.hasNextButtonTarget) this.nextButtonTarget.hidden = !many;

    if (this.hasIndicatorsTarget) {
      if (!many) {
        this.indicatorsTarget.hidden = true;
        this.indicatorsTarget.innerHTML = "";
      } else {
        this.indicatorsTarget.hidden = false;
        this.indicatorsTarget.innerHTML = this.#previews
          .map(
            (_p, i) =>
              `<button type="button" class="file-upload__dot${
                i === this.#currentIndex ? " is-active" : ""
              }" data-index="${i}" data-action="file-upload#goTo" aria-label="Show file ${i + 1}"></button>`,
          )
          .join("");
      }
    }
  }

  #displayPreviewShell(filename) {
    if (this.hasPreviewTarget) this.previewTarget.hidden = false;
    if (this.hasPlaceholderTarget) this.placeholderTarget.hidden = true;
    if (this.hasFilenameTarget) {
      this.filenameTarget.textContent = filename;
      this.filenameTarget.hidden = false;
    }
    if (this.inputTarget?.multiple && this.hasAddMoreTarget)
      this.addMoreTarget.hidden = false;
    if (this.hasDropzoneTarget)
      this.dropzoneTarget.classList.add(DROPZONE_FILLED_CLASS);
  }

  #clearPreview() {
    if (this.hasPreviewTarget) {
      this.previewTarget.innerHTML = "";
      this.previewTarget.hidden = true;
    }
    if (this.hasPlaceholderTarget) this.placeholderTarget.hidden = false;
    if (this.hasFilenameTarget) {
      this.filenameTarget.textContent = "";
      this.filenameTarget.hidden = true;
    }
    if (this.hasIndicatorsTarget) {
      this.indicatorsTarget.innerHTML = "";
      this.indicatorsTarget.hidden = true;
    }
    if (this.hasAddMoreTarget) this.addMoreTarget.hidden = true;
    if (this.hasDropzoneTarget)
      this.dropzoneTarget.classList.remove(DROPZONE_FILLED_CLASS);
  }

  #showProgress(value) {
    if (!this.hasProgressTarget || !this.hasProgressBarTarget) return;
    this.progressTarget.hidden = false;
    this.progressBarTarget.style.width = `${Math.max(0, Math.min(100, value))}%`;
  }

  #hideProgress() {
    if (!this.hasProgressTarget || !this.hasProgressBarTarget) return;
    this.progressTarget.hidden = true;
    this.progressBarTarget.style.width = "0%";
  }

  #showStatus(message, tone = "info") {
    if (!this.hasStatusTarget) return;
    this.statusTarget.textContent = message;
    this.statusTarget.dataset.tone = tone;
    this.statusTarget.hidden = false;
  }

  #clearStatus() {
    if (!this.hasStatusTarget) return;
    this.statusTarget.textContent = "";
    delete this.statusTarget.dataset.tone;
    this.statusTarget.hidden = true;
  }

  #validateFileSize(file) {
    console.log(this.hasMaxSizeValue);
    return (
      !this.hasMaxSizeValue ||
      !this.maxSizeValue ||
      file.size <= this.maxSizeValue
    );
  }

  #rejectFile(file) {
    this.inputTarget.value = "";
    this.inputTarget.files = new DataTransfer().files;
    this.#clearPreview();
    const sizeMsg = this.hasMaxSizeValue
      ? ` (max ${this.#humanMaxSize()})`
      : "";
    this.#showStatus(`"${file.name}" is too large${sizeMsg}.`, "error");
  }

  #reset() {
    this.#clearPreview();
    this.#clearStatus();
    this.#hideProgress();
  }

  #humanMaxSize() {
    if (!this.hasMaxSizeValue || !this.maxSizeValue) return "";
    const mb = this.maxSizeValue / (1024 * 1024);
    return `${mb.toFixed(mb >= 10 ? 0 : 1)} MB`;
  }
}
