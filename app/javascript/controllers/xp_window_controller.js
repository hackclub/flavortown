import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "titlebar",
    "resizeHandle",
    "errorDialog",
    "errorSound",
    "errorText",
  ];

  static errorMessages = [
    "something happened",
    "task failed successfully",
    "exception in exception handler",
  ];

  connect() {
    this.isDragging = false;
    this.isResizing = false;
    this.hasMoved = false;
    this.dragThreshold = 5;

    this.startX = 0;
    this.startY = 0;
    this.offsetX = 0;
    this.offsetY = 0;

    // Bind handlers
    this.onMouseMove = this.onMouseMove.bind(this);
    this.onMouseUp = this.onMouseUp.bind(this);
    this.onTouchMove = this.onTouchMove.bind(this);
    this.onTouchEnd = this.onTouchEnd.bind(this);
  }

  disconnect() {
    document.removeEventListener("mousemove", this.onMouseMove);
    document.removeEventListener("mouseup", this.onMouseUp);
    document.removeEventListener("touchmove", this.onTouchMove);
    document.removeEventListener("touchend", this.onTouchEnd);
  }

  // --- Drag (titlebar) ---

  dragStart(event) {
    if (this.isMobile() || this.minimized) return;
    if (event.button !== 0) return;

    this.dragTarget = this.findDragTarget(event.currentTarget);
    this.isDragging = true;
    this.hasMoved = false;

    const rect = this.dragTarget.getBoundingClientRect();
    this.startX = event.clientX;
    this.startY = event.clientY;
    this.offsetX = event.clientX - rect.left;
    this.offsetY = event.clientY - rect.top;

    document.addEventListener("mousemove", this.onMouseMove);
    document.addEventListener("mouseup", this.onMouseUp);
    event.preventDefault();
  }

  dragTouchStart(event) {
    if (this.isMobile() || this.minimized) return;
    const touch = event.touches[0];

    this.dragTarget = this.findDragTarget(event.currentTarget);
    this.isDragging = true;
    this.hasMoved = false;

    const rect = this.dragTarget.getBoundingClientRect();
    this.startX = touch.clientX;
    this.startY = touch.clientY;
    this.offsetX = touch.clientX - rect.left;
    this.offsetY = touch.clientY - rect.top;

    document.addEventListener("touchmove", this.onTouchMove, {
      passive: false,
    });
    document.addEventListener("touchend", this.onTouchEnd);
  }

  findDragTarget(titleBar) {
    // If the title bar belongs to the error dialog, drag the dialog itself
    const parentWindow = titleBar.closest(".window");
    if (parentWindow && parentWindow === this.errorDialogTarget) {
      return parentWindow;
    }
    // Otherwise drag the wrapper
    return this.element;
  }

  onMouseMove(event) {
    if (this.isDragging) {
      this.handleDragMove(event.clientX, event.clientY);
    } else if (this.isResizing) {
      this.handleResizeMove(event.clientX, event.clientY);
    }
  }

  onTouchMove(event) {
    const touch = event.touches[0];
    if (this.isDragging) {
      event.preventDefault();
      this.handleDragMove(touch.clientX, touch.clientY);
    } else if (this.isResizing) {
      event.preventDefault();
      this.handleResizeMove(touch.clientX, touch.clientY);
    }
  }

  handleDragMove(clientX, clientY) {
    const dx = clientX - this.startX;
    const dy = clientY - this.startY;

    if (
      !this.hasMoved &&
      Math.abs(dx) < this.dragThreshold &&
      Math.abs(dy) < this.dragThreshold
    ) {
      return;
    }

    if (!this.hasMoved) {
      this.hasMoved = true;
      // Only detach the main window from flow, not the error dialog
      if (this.dragTarget === this.element) {
        this.detachFromFlow();
      }
    }

    this.dragTarget.style.left = `${clientX - this.offsetX}px`;
    this.dragTarget.style.top = `${clientY - this.offsetY}px`;
  }

  onMouseUp() {
    this.isDragging = false;
    this.isResizing = false;
    document.removeEventListener("mousemove", this.onMouseMove);
    document.removeEventListener("mouseup", this.onMouseUp);
  }

  onTouchEnd() {
    this.isDragging = false;
    this.isResizing = false;
    document.removeEventListener("touchmove", this.onTouchMove);
    document.removeEventListener("touchend", this.onTouchEnd);
  }

  // --- Resize (bottom-right handle) ---

  resizeStart(event) {
    if (this.isMobile()) return;
    if (event.button !== 0) return;

    this.isResizing = true;
    this.detachFromFlow();
    this.resizeStartX = event.clientX;
    this.resizeStartY = event.clientY;
    this.resizeStartW = this.element.offsetWidth;
    this.resizeStartH = this.element.offsetHeight;

    document.addEventListener("mousemove", this.onMouseMove);
    document.addEventListener("mouseup", this.onMouseUp);
    event.preventDefault();
    event.stopPropagation();
  }

  handleResizeMove(clientX, clientY) {
    const newW = this.resizeStartW + (clientX - this.resizeStartX);
    const newH = this.resizeStartH + (clientY - this.resizeStartY);
    this.element.style.width = `${Math.max(200, newW)}px`;
    this.element.style.height = `${Math.max(100, newH)}px`;
  }

  // --- Helpers ---

  detachFromFlow() {
    if (this.detached) return;
    this.detached = true;

    const rect = this.element.getBoundingClientRect();

    // Insert a placeholder to preserve layout space
    this.placeholder = document.createElement("div");
    this.placeholder.style.width = `${rect.width}px`;
    this.placeholder.style.height = `${rect.height}px`;
    this.placeholder.style.visibility = "hidden";
    this.element.parentNode.insertBefore(this.placeholder, this.element);

    this.element.style.position = "absolute";
    this.element.style.left = `${rect.left + window.scrollX}px`;
    this.element.style.top = `${rect.top + window.scrollY}px`;
    this.element.style.width = `${rect.width}px`;
    this.element.style.zIndex = "1000";
    this.element.classList.add("xp-window-wrapper--detached");
  }

  // --- Window controls ---

  close(event) {
    event.stopPropagation();
    this.element.style.display = "none";
    if (this.placeholder) this.placeholder.style.display = "none";
  }

  minimize(event) {
    event.stopPropagation();
    if (this.minimized) {
      this.restore(event);
      return;
    }
    this.minimized = true;

    // Save pre-minimize state so we can restore
    this.preMinimizeStyles = {
      position: this.element.style.position,
      left: this.element.style.left,
      top: this.element.style.top,
      width: this.element.style.width,
      height: this.element.style.height,
      zIndex: this.element.style.zIndex,
    };

    this.element.style.position = "fixed";
    this.element.style.bottom = "0";
    this.element.style.left = "8px";
    this.element.style.top = "auto";
    this.element.style.width = "200px";
    this.element.style.height = "auto";
    this.element.style.zIndex = "10000";
    this.element.classList.add("xp-window-wrapper--minimized");
  }

  restore(event) {
    event.stopPropagation();
    if (!this.minimized) return;
    this.minimized = false;

    this.element.classList.remove("xp-window-wrapper--minimized");

    if (this.preMinimizeStyles) {
      Object.assign(this.element.style, this.preMinimizeStyles);
      this.element.style.bottom = "";
      this.preMinimizeStyles = null;
    }
  }

  showError(event) {
    event.stopPropagation();
    const dialog = this.errorDialogTarget;
    dialog.style.display = "";
    dialog.style.position = "fixed";
    dialog.style.left = "50%";
    dialog.style.top = "50%";
    dialog.style.transform = "translate(-50%, -50%)";
    dialog.style.zIndex = "10001";

    const messages = this.constructor.errorMessages;
    this.errorTextTarget.textContent =
      messages[Math.floor(Math.random() * messages.length)];

    if (this.hasErrorSoundTarget) {
      this.errorSoundTarget.currentTime = 0;
      this.errorSoundTarget.play().catch(() => {});
    }
  }

  closeError(event) {
    event.stopPropagation();
    this.errorDialogTarget.style.display = "none";
  }

  isMobile() {
    return window.innerWidth < 768;
  }
}
