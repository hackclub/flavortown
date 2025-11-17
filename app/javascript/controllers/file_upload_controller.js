import { Controller } from "@hotwired/stimulus";

const DROPZONE_ACTIVE_CLASS = "file-upload__dropzone--active";
const DROPZONE_FILLED_CLASS = "file-upload__dropzone--filled";

export default class extends Controller {
  #processing = false;

  static targets = [
    "input",
    "dropzone",
    "placeholder",
    "preview",
    "filename",
    "progress",
    "progressBar",
    "status",
  ];
  static values = {
    maxSize: Number,
    initialUrl: String,
    initialFilename: String,
  };

  connect() {
    this.#reset();
    // Show existing preview if provided
    if (this.hasInitialUrlValue && this.initialUrlValue) {
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
    this.#showPreview(file);
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
    const file = Array.from(fileList || [])[0];
    if (!file) return;

    if (!this.#validateFileSize(file)) {
      this.#rejectFile(file);
      return;
    }

    this.#processing = true;
    try {
      const dt = new DataTransfer();
      dt.items.add(file);
      this.inputTarget.files = dt.files;
      this.#showPreview(file);
      this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }));
    } finally {
      this.#processing = false;
    }
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

  #displayPreviewShell(filename) {
    if (this.hasPreviewTarget) this.previewTarget.hidden = false;
    if (this.hasPlaceholderTarget) this.placeholderTarget.hidden = true;
    if (this.hasFilenameTarget) {
      this.filenameTarget.textContent = filename;
      this.filenameTarget.hidden = false;
    }
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
