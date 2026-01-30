import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = {
    targetId: String,
    position: { type: String, default: "top" },
  };

  connect() {
    this.boundShow = this.show.bind(this);
    this.boundHide = this.hide.bind(this);
    this.boundUpdatePosition = () => {
      if (!this.element.classList.contains("tooltip--visible")) return;
      requestAnimationFrame(() => this.updatePosition());
    };

    this.targetElement = document.getElementById(this.targetIdValue);

    if (!this.targetElement) {
      console.warn(`Tooltip target #${this.targetIdValue} not found`);
      return;
    }

    this.targetElement.addEventListener("mouseenter", this.boundShow, {
      passive: true,
    });
    this.targetElement.addEventListener("mouseleave", this.boundHide, {
      passive: true,
    });
    this.targetElement.addEventListener("focus", this.boundShow);
    this.targetElement.addEventListener("blur", this.boundHide);

    window.addEventListener("scroll", this.boundUpdatePosition, {
      passive: true,
    });
    window.addEventListener("resize", this.boundUpdatePosition, {
      passive: true,
    });

    this.ensureInBody();
    requestAnimationFrame(() => this.ensureInBody());
  }

  disconnect() {
    if (this.targetElement) {
      this.targetElement.removeEventListener("mouseenter", this.boundShow);
      this.targetElement.removeEventListener("mouseleave", this.boundHide);
      this.targetElement.removeEventListener("focus", this.boundShow);
      this.targetElement.removeEventListener("blur", this.boundHide);
    }

    if (this.boundUpdatePosition) {
      window.removeEventListener("scroll", this.boundUpdatePosition);
      window.removeEventListener("resize", this.boundUpdatePosition);
    }

    if (this.element.parentElement === document.body) {
      this.element.remove();
    }
  }

  ensureInBody() {
    if (this.element.parentElement !== document.body) {
      document.body.appendChild(this.element);
    }
  }

  show() {
    this.ensureInBody();

    this.element.classList.add("tooltip--visible");
    this.element.setAttribute("aria-hidden", "false");
    this.updatePosition();
  }

  hide() {
    this.element.classList.remove("tooltip--visible");
    this.element.setAttribute("aria-hidden", "true");
  }

  updatePosition() {
    if (!this.targetElement) return;

    const targetRect = this.targetElement.getBoundingClientRect();
    const gap = 8;

    this.element.style.top = "0";
    this.element.style.left = "0";
    this.element.style.visibility = "hidden";
    this.element.classList.add("tooltip--visible");

    const tooltipRect = this.element.getBoundingClientRect();

    this.element.style.visibility = "";

    const scrollY = window.scrollY;
    const scrollX = window.scrollX;

    let top, left;

    switch (this.positionValue) {
      case "bottom":
        top = targetRect.bottom + scrollY + gap;
        left =
          targetRect.left +
          scrollX +
          targetRect.width / 2 -
          tooltipRect.width / 2;
        break;
      case "left":
        top =
          targetRect.top +
          scrollY +
          targetRect.height / 2 -
          tooltipRect.height / 2;
        left = targetRect.left + scrollX - tooltipRect.width - gap;
        break;
      case "right":
        top =
          targetRect.top +
          scrollY +
          targetRect.height / 2 -
          tooltipRect.height / 2;
        left = targetRect.right + scrollX + gap;
        break;
      case "top":
      default:
        top = targetRect.top + scrollY - tooltipRect.height - gap;
        left =
          targetRect.left +
          scrollX +
          targetRect.width / 2 -
          tooltipRect.width / 2;
        break;
    }

    const viewportWidth = window.innerWidth;
    const viewportHeight = window.innerHeight;

    left = Math.min(Math.max(left, 8), viewportWidth - tooltipRect.width - 8);
    top = Math.min(
      Math.max(top, scrollY + 8),
      scrollY + viewportHeight - tooltipRect.height - 8,
    );

    this.element.style.top = `${top}px`;
    this.element.style.left = `${left}px`;
  }
}
