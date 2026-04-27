import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["slide", "segment"];
  static values = {
    current: { type: Number, default: 0 },
    interval: { type: Number, default: 8000 },
    cookies: { type: Number, default: 0 },
    ships: { type: Number, default: 0 },
    votes: { type: Number, default: 0 },
    devlogs: { type: Number, default: 0 },
    coding: { type: Number, default: 0 },
    rank: { type: Number, default: -1 },
    username: { type: String, default: "" },
  };

  connect() {
    this.showSlide(0);
    this.startTimer();
  }

  disconnect() {
    this.stopTimer();
  }

  click(event) {
    event.preventDefault();
    event.stopPropagation();

    const rect = this.element.getBoundingClientRect();
    const x = event.clientX - rect.left;
    if (x < rect.width / 4) {
      this.back();
    } else {
      this.advance();
    }
  }

  advance() {
    const next = this.currentValue + 1;
    if (next < this.slideTargets.length) {
      this.showSlide(next);
      this.resetTimer();
    }
  }

  back() {
    const prev = this.currentValue - 1;
    if (prev >= 0) {
      this.showSlide(prev);
      this.resetTimer();
    }
  }

  showSlide(index) {
    this.currentValue = index;

    this.slideTargets.forEach((slide, i) => {
      slide.classList.remove("active", "prev");
      if (i === index) slide.classList.add("active");
      if (i === index - 1) slide.classList.add("prev");
    });

    this.segmentTargets.forEach((seg, i) => {
      seg.classList.remove("filled", "current", "empty");
      if (i < index) seg.classList.add("filled");
      else if (i === index) seg.classList.add("current");
      else seg.classList.add("empty");
    });

    const currentSeg = this.segmentTargets[index];
    if (currentSeg) {
      currentSeg.style.setProperty("--segment-duration", `${this.intervalValue}ms`);
    }
  }

  startTimer() {
    this.timer = setInterval(() => this.advance(), this.intervalValue);
  }

  stopTimer() {
    if (this.timer) clearInterval(this.timer);
  }

  resetTimer() {
    this.stopTimer();
    this.startTimer();
  }

  async download(event) {
    event.stopPropagation();

    await document.fonts.ready;

    const W = 900, H = 520;
    const canvas = document.createElement("canvas");
    canvas.width = W;
    canvas.height = H;
    const ctx = canvas.getContext("2d");

    // Background
    ctx.fillStyle = "#0d0d0d";
    ctx.fillRect(0, 0, W, H);

    // Header
    const headerH = 72;
    const pad = 16;
    this.#roundRect(ctx, pad, pad, W - pad * 2, headerH, 12);
    ctx.fillStyle = "#1a1a1a";
    ctx.fill();

    ctx.fillStyle = "#ffffff";
    ctx.font = "bold 26px 'Jua', 'Arial Black', sans-serif";
    ctx.textBaseline = "middle";
    ctx.textAlign = "left";
    ctx.fillText("flavortown wrapped", pad + 20, pad + headerH / 2);

    ctx.fillStyle = "rgba(255,255,255,0.45)";
    ctx.font = "16px 'Jua', 'Arial Black', sans-serif";
    ctx.textAlign = "right";
    ctx.fillText(`@${this.usernameValue}`, W - pad - 20, pad + headerH / 2);

    // Stat grid
    const rankLabel = this.rankValue >= 0 ? `top ${100 - this.rankValue}%` : "—";
    const cells = [
      { label: "cookies earned", value: this.cookiesValue.toLocaleString(), from: "hsl(31,63%,46%)", to: "hsl(21,52%,30%)" },
      { label: "projects shipped", value: String(this.shipsValue), from: "hsl(105,44%,30%)", to: "hsl(90,43%,20%)" },
      { label: "votes cast", value: this.votesValue.toLocaleString(), from: "hsl(178,46%,35%)", to: "hsl(204,44%,22%)" },
      { label: "devlogs written", value: String(this.devlogsValue), from: "hsl(356,47%,45%)", to: "hsl(348,28%,20%)" },
      { label: "hours coded", value: String(this.codingValue), from: "hsl(218,44%,20%)", to: "hsl(204,44%,12%)" },
      { label: "leaderboard", value: rankLabel, from: "hsl(36,70%,45%)", to: "hsl(21,52%,28%)" },
    ];

    const cols = 3, rows = 2, gap = 10;
    const gridTop = pad + headerH + gap;
    const cellW = (W - pad * 2 - gap * (cols - 1)) / cols;
    const cellH = (H - gridTop - pad - gap * (rows - 1)) / rows;

    cells.forEach((cell, i) => {
      const col = i % cols;
      const row = Math.floor(i / cols);
      const x = pad + col * (cellW + gap);
      const y = gridTop + row * (cellH + gap);

      const grad = ctx.createLinearGradient(x, y, x + cellW, y + cellH);
      grad.addColorStop(0, cell.from);
      grad.addColorStop(1, cell.to);
      this.#roundRect(ctx, x, y, cellW, cellH, 12);
      ctx.fillStyle = grad;
      ctx.fill();

      // Value — scale font to fit
      const maxValW = cellW - 32;
      ctx.textAlign = "left";
      ctx.textBaseline = "alphabetic";
      ctx.fillStyle = "#ffffff";
      let fontSize = 52;
      ctx.font = `bold ${fontSize}px 'Jua', 'Arial Black', sans-serif`;
      while (ctx.measureText(cell.value).width > maxValW && fontSize > 20) {
        fontSize -= 2;
        ctx.font = `bold ${fontSize}px 'Jua', 'Arial Black', sans-serif`;
      }
      ctx.fillText(cell.value, x + 16, y + cellH - 36);

      // Label
      ctx.fillStyle = "rgba(255,255,255,0.6)";
      ctx.font = "13px 'Jua', 'Arial Black', sans-serif";
      ctx.fillText(cell.label, x + 16, y + cellH - 16);
    });

    const link = document.createElement("a");
    link.download = "flavortown-wrapped.png";
    link.href = canvas.toDataURL("image/png");
    link.click();
  }

  #roundRect(ctx, x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + w - r, y);
    ctx.quadraticCurveTo(x + w, y, x + w, y + r);
    ctx.lineTo(x + w, y + h - r);
    ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
    ctx.lineTo(x + r, y + h);
    ctx.quadraticCurveTo(x, y + h, x, y + h - r);
    ctx.lineTo(x, y + r);
    ctx.quadraticCurveTo(x, y, x + r, y);
    ctx.closePath();
  }
}
