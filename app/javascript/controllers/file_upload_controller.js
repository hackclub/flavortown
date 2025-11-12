import { Controller } from "@hotwired/stimulus"

const DROPZONE_ACTIVE_CLASS = "file-upload__dropzone--active"
const DROPZONE_FILLED_CLASS = "file-upload__dropzone--filled"

class FileUploadView {
  constructor(controller) {
    this.controller = controller
  }

  openFilePicker() {
    this.controller.inputTarget.click()
  }

  activateDropzone() {
    if (this.controller.hasDropzoneTarget) {
      this.controller.dropzoneTarget.classList.add(DROPZONE_ACTIVE_CLASS)
    }
  }

  deactivateDropzone() {
    if (this.controller.hasDropzoneTarget) {
      this.controller.dropzoneTarget.classList.remove(DROPZONE_ACTIVE_CLASS)
    }
  }

  markFilled(state = true) {
    if (!this.controller.hasDropzoneTarget) return
    const action = state ? "add" : "remove"
    this.controller.dropzoneTarget.classList[action](DROPZONE_FILLED_CLASS)
  }

  showPreview(file) {
    if (!this.controller.hasPreviewTarget) return

    if (file.type.startsWith("image/")) {
      const reader = new FileReader()
      reader.onload = () => {
        this.#renderPreviewImage(reader.result, file.name) 
      }
      reader.readAsDataURL(file)
    } else {
      this.#renderPreviewFallback(file.name)
    }
  }

  #renderPreviewImage(src, alt) {
    this.controller.previewTarget.innerHTML = `<img src="${src}" alt="${alt}" class="file-upload__preview-image" />`
    this.#displayPreviewShell(alt)
  }

  #renderPreviewFallback(filename) {
    this.controller.previewTarget.innerHTML = `<div class="file-upload__preview-fallback">${filename}</div>`
    this.#displayPreviewShell(filename)
  }

  #displayPreviewShell(filename) {
    if (this.controller.hasPreviewTarget) {
      this.controller.previewTarget.hidden = false
    }
    if (this.controller.hasPlaceholderTarget) {
      this.controller.placeholderTarget.hidden = true
    }
    if (this.controller.hasFilenameTarget) {
      this.controller.filenameTarget.textContent = filename
      this.controller.filenameTarget.hidden = false
    }
    this.markFilled(true)
  }

  clearPreview() {
    if (this.controller.hasPreviewTarget) {
      this.controller.previewTarget.innerHTML = ""
      this.controller.previewTarget.hidden = true
    }

    if (this.controller.hasPlaceholderTarget) {
      this.controller.placeholderTarget.hidden = false
    }

    if (this.controller.hasFilenameTarget) {
      this.controller.filenameTarget.textContent = ""
      this.controller.filenameTarget.hidden = true
    }

    this.markFilled(false)
  }

  showProgress(value) {
    if (!this.controller.hasProgressTarget || !this.controller.hasProgressBarTarget) return

    this.controller.progressTarget.hidden = false
    this.controller.progressBarTarget.style.width = `${Math.max(0, Math.min(100, value))}%`
  }

  hideProgress() {
    if (!this.controller.hasProgressTarget || !this.controller.hasProgressBarTarget) return

    this.controller.progressTarget.hidden = true
    this.controller.progressBarTarget.style.width = "0%"
  }

  showStatus(message, tone = "info") {
    if (!this.controller.hasStatusTarget) return

    this.controller.statusTarget.textContent = message
    this.controller.statusTarget.dataset.tone = tone
    this.controller.statusTarget.hidden = false
  }

  clearStatus() {
    if (!this.controller.hasStatusTarget) return

    this.controller.statusTarget.textContent = ""
    delete this.controller.statusTarget.dataset.tone
    this.controller.statusTarget.hidden = true
  }
}

// Connects to data-controller="file-upload"
export default class extends Controller {
  static targets = [
    "input",
    "dropzone",
    "placeholder",
    "preview",
    "filename",
    "progress",
    "progressBar",
    "status"
  ]

  static values = {
    maxSize: Number
  }

  connect() {
    this.view = new FileUploadView(this)
    this.#reset()
  }

  open(event) {
    event.preventDefault()
    this.view.openFilePicker()
  }

  openWithKeyboard(event) {
    if (event.key !== "Enter" && event.key !== " ") return

    event.preventDefault()
    this.view.openFilePicker()
  }

  dragOver(event) {
    event.preventDefault()
    this.view.activateDropzone()
  }

  dragLeave(event) {
    event.preventDefault()
    this.view.deactivateDropzone()
  }

  drop(event) {
    event.preventDefault()
    this.view.deactivateDropzone()
    this.#processFiles(event.dataTransfer?.files)
  }

  handleSelection(event) {
    this.#processFiles(event.target.files)
  }

  uploadInitialize(event) {
    const { file } = event.detail

    if (!this.#validateFileSize(file)) {
      event.preventDefault()
      this.#rejectFile(file)
      return
    }

    this.view.showPreview(file)
    this.view.showProgress(0)
    this.view.showStatus("Preparing upload…")
  }

  uploadStart(event) {
    this.view.showProgress(0)
    this.view.showStatus(`Uploading ${event.detail.file.name}…`)
  }

  uploadProgress(event) {
    this.view.showProgress(event.detail.progress)
  }

  uploadError(event) {
    event.preventDefault()
    this.view.hideProgress()
    this.view.showStatus(event.detail.error, "error")
  }

  uploadEnd() {
    this.view.showProgress(100)
    this.view.showStatus("Upload complete", "success")

    window.setTimeout(() => {
      this.view.hideProgress()
      this.view.clearStatus()
    }, 1200)
  }

  #processFiles(fileList) {
    const files = Array.from(fileList || [])
    if (!files.length) return

    const [ file ] = files

    if (!this.#validateFileSize(file)) {
      this.#rejectFile(file)
      return
    }

    this.#assignFiles([ file ])
    this.#triggerInputChange()
    this.view.showPreview(file)
    this.view.showStatus("Ready to upload")
  }

  #assignFiles(fileList) {
    const dataTransfer = new DataTransfer()

    Array.from(fileList).forEach((file) => dataTransfer.items.add(file))
    this.inputTarget.files = dataTransfer.files
  }

  #triggerInputChange() {
    const event = new Event("change", { bubbles: true })
    this.inputTarget.dispatchEvent(event)
  }

  #validateFileSize(file) {
    if (!this.hasMaxSizeValue || !this.maxSizeValue) return true
    return file.size <= this.maxSizeValue
  }

  #rejectFile(file) {
    this.#clearInput()
    this.view.clearPreview()
    const sizeMessage = this.hasMaxSizeValue ? ` (max ${this.#humanMaxSize()})` : ""
    this.view.showStatus(`"${file.name}" is too large${sizeMessage}.`, "error")
  }

  #clearInput() {
    this.inputTarget.value = ""
    this.inputTarget.files = new DataTransfer().files
  }

  #reset() {
    this.view.clearPreview()
    this.view.clearStatus()
    this.view.hideProgress()
  }

  #humanMaxSize() {
    if (!this.hasMaxSizeValue || !this.maxSizeValue) return ""

    const megabytes = this.maxSizeValue / (1024 * 1024)
    const precision = megabytes >= 10 ? 0 : 1
    return `${megabytes.toFixed(precision)} MB`
  }
}
