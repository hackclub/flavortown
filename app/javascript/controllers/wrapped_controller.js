import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["slide", "segment"];
  static values = {
    current: { type: Number, default: 0 },
    interval: { type: Number, default: 8000 },
    cookies: { type: Number, default: 0 },
    ships: { type: Number, default: 0 },
    devlogs: { type: Number, default: 0 },
    coding: { type: Number, default: 0 },
    username: { type: String, default: "" },
    bento: { type: Object, default: {} },
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
      currentSeg.style.setProperty(
        "--segment-duration",
        `${this.intervalValue}ms`,
      );
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

    // Flavortown palette — warm dark backgrounds with gold/cream accents.
    const palette = {
      bg: "#1a0f0d", // page background
      card: "#2a1d1c", // primary card
      subcard: "#1f1413", // nested card
      accent: "hsl(36, 70%, 56%)", // yellow-450 (primary highlight)
      cream: "#f5e6d0", // headline text
      muted: "rgba(245,230,208,0.55)", // labels
      donut: [
        // donut slice palette
        "hsl(36, 70%, 56%)", // gold (top source)
        "hsl(105, 44%, 46%)", // green
        "hsl(204, 44%, 52%)", // blue
        "hsl(356, 47%, 52%)", // red
        "hsl(30, 46%, 71%)", // tan
        "hsl(8, 30%, 36%)", // brown
      ],
    };

    const W = 1800,
      H = 1080;
    const canvas = document.createElement("canvas");
    canvas.width = W;
    canvas.height = H;
    const ctx = canvas.getContext("2d");

    ctx.fillStyle = palette.bg;
    ctx.fillRect(0, 0, W, H);

    const bento = this.bentoValue || {};
    const pad = 48;
    const gap = 24;
    const radius = 22;

    // ── Header ───────────────────────────────────────────────────────
    const headerY = pad;
    ctx.fillStyle = palette.muted;
    ctx.font = "500 22px 'Jua', 'Arial Black', sans-serif";
    ctx.textBaseline = "top";
    ctx.textAlign = "left";
    ctx.fillText("Flavortown Wrapped", pad, headerY);

    ctx.fillStyle = palette.cream;
    ctx.font = "bold 64px 'Jua', 'Arial Black', sans-serif";
    const nameY = headerY + 32;
    // Lightning bolt glyph then username
    ctx.fillStyle = palette.accent;
    ctx.fillText("⚡", pad, nameY);
    const boltWidth = ctx.measureText("⚡").width + 14;
    ctx.fillStyle = palette.cream;
    ctx.fillText(this.usernameValue, pad + boltWidth, nameY);
    // Role badges after username
    const roleBadges = bento.role_badges || [];
    if (roleBadges.length > 0) {
      const nameWidth = ctx.measureText(this.usernameValue).width;
      let badgeX = pad + boltWidth + nameWidth + 18;
      ctx.font = "52px sans-serif";
      for (const badge of roleBadges) {
        ctx.fillText(badge, badgeX, nameY);
        badgeX += ctx.measureText(badge).width + 10;
      }
      ctx.font = "bold 64px 'Jua', 'Arial Black', sans-serif";
    }

    // ── Layout grid ─────────────────────────────────────────────────
    const contentTop = nameY + 110;
    const contentBottom = H - pad;
    const contentH = contentBottom - contentTop;
    const leftW = Math.round((W - pad * 2 - gap) * 0.6);
    const rightW = W - pad * 2 - gap - leftW;
    const leftX = pad;
    const rightX = pad + leftW + gap;

    // Row heights inside the left column
    const topRowH = Math.round(contentH * 0.36);
    const midRowH = Math.round(contentH * 0.18);
    const bottomRowH = contentH - topRowH - midRowH - gap * 2;

    // ── Total Earned (top, full width) ──────────────────────────────
    const topW = W - pad * 2;
    this.#drawBentoCard(
      ctx,
      leftX,
      contentTop,
      topW,
      topRowH,
      radius,
      palette.card,
    );
    const totalNumber = (
      bento.total_cookies ?? this.cookiesValue
    ).toLocaleString();
    const cardPad = 36;

    ctx.fillStyle = palette.cream;
    ctx.font = "500 22px 'Jua', 'Arial Black', sans-serif";
    ctx.textBaseline = "top";
    ctx.fillText("Total Earned", leftX + cardPad, contentTop + cardPad);

    ctx.font = "bold 130px 'Jua', 'Arial Black', sans-serif";
    ctx.fillText(totalNumber, leftX + cardPad, contentTop + cardPad + 48);

    ctx.font = "500 26px 'Jua', 'Arial Black', sans-serif";
    ctx.fillStyle = palette.muted;
    ctx.fillText(
      bento.hours_label ?? `${this.codingValue}h built`,
      leftX + cardPad,
      contentTop + topRowH - cardPad - 30,
    );

    // Donut chart parked on the right side of the Total Earned card.
    const donutCx = leftX + topW - cardPad - 150;
    const donutCy = contentTop + topRowH / 2 - 6;
    this.#drawDonut(ctx, donutCx, donutCy, 140, 92, bento.top_source, palette);

    if (bento.top_source?.label) {
      ctx.fillStyle = palette.muted;
      ctx.font = "500 18px 'Jua', 'Arial Black', sans-serif";
      ctx.textAlign = "center";
      ctx.fillText(
        `Top source: ${bento.top_source.label}`,
        donutCx,
        contentTop + topRowH - cardPad - 4,
      );
      ctx.textAlign = "left";
    }

    // ── Middle row: 4 small stat cards (left) ───────────────────────
    const midY = contentTop + topRowH + gap;
    const smallCount = 4;
    const smallGap = gap;
    const smallW = (leftW - smallGap * (smallCount - 1)) / smallCount;
    const smallStats = [
      { label: "Devlogs", value: bento.devlogs ?? this.devlogsValue },
      { label: "Ships", value: bento.ships ?? this.shipsValue },
      { label: "Orders", value: bento.orders ?? 0 },
      {
        label: "Cookies Spent",
        value: (bento.cookies_spent ?? 0).toLocaleString(),
      },
    ];
    smallStats.forEach((stat, i) => {
      const x = leftX + i * (smallW + smallGap);
      this.#drawBentoCard(ctx, x, midY, smallW, midRowH, radius, palette.card);
      ctx.fillStyle = palette.muted;
      ctx.font = "500 18px 'Jua', 'Arial Black', sans-serif";
      ctx.fillText(stat.label, x + 24, midY + 22);

      ctx.fillStyle = palette.cream;
      ctx.font = "bold 56px 'Jua', 'Arial Black', sans-serif";
      ctx.fillText(String(stat.value), x + 24, midY + midRowH - 24 - 56);
    });

    // ── Activity Pulse (bottom-left) ────────────────────────────────
    const pulseY = midY + midRowH + gap;
    this.#drawBentoCard(
      ctx,
      leftX,
      pulseY,
      leftW,
      bottomRowH,
      radius,
      palette.card,
    );
    ctx.fillStyle = palette.cream;
    ctx.font = "500 22px 'Jua', 'Arial Black', sans-serif";
    ctx.fillText("Activity Pulse", leftX + cardPad, pulseY + cardPad);

    this.#drawHeatmap(
      ctx,
      leftX + cardPad,
      pulseY + cardPad + 40,
      Math.floor(leftW * 0.45),
      bottomRowH - cardPad * 2 - 40,
      bento.activity_pulse ?? [],
      palette,
    );

    // Pulse summary text on the right side of the card
    const summaryX = leftX + Math.floor(leftW * 0.5) + 16;
    const summaryYStart = pulseY + cardPad + 56;
    const summaryLines = [
      `${bento.active_days ?? 0} active days`,
      `${(bento.tracked_hours ?? this.codingValue).toFixed?.(1) ?? bento.tracked_hours ?? this.codingValue} tracked hours`,
      `${bento.projects_touched ?? 0} projects touched`,
      `${bento.orders ?? 0} orders`,
    ];
    ctx.fillStyle = palette.cream;
    ctx.font = "500 28px 'Jua', 'Arial Black', sans-serif";
    summaryLines.forEach((line, i) => {
      ctx.fillText(line, summaryX, summaryYStart + i * 44);
    });

    // ── Highlights (right column, spans middle + bottom) ────────────
    const highlightsY = midY;
    const highlightsH = midRowH + gap + bottomRowH;
    this.#drawBentoCard(
      ctx,
      rightX,
      highlightsY,
      rightW,
      highlightsH,
      radius,
      palette.card,
    );
    ctx.fillStyle = palette.cream;
    ctx.font = "500 22px 'Jua', 'Arial Black', sans-serif";
    ctx.fillText("Highlights", rightX + cardPad, highlightsY + cardPad);

    const subGap = 20;
    const subW = (rightW - cardPad * 2 - subGap) / 2;
    const subH = (highlightsH - cardPad * 2 - 40 - subGap) / 2;
    const subTop = highlightsY + cardPad + 50;
    const highlightCells = [
      {
        label: "Biggest Gain",
        value: bento.biggest_gain
          ? `${bento.biggest_gain.amount.toLocaleString()} cookies`
          : "—",
        caption: bento.biggest_gain?.date ?? "",
      },
      {
        label: "Biggest Spend",
        value: bento.biggest_spend
          ? `${bento.biggest_spend.amount.toLocaleString()} cookies`
          : "—",
        caption: bento.biggest_spend?.date ?? "",
      },
      {
        label: "Peak Workday",
        value: bento.peak_workday ? `${bento.peak_workday.hours}h` : "—",
        caption: bento.peak_workday
          ? `${bento.peak_workday.date} — hours peak`
          : "",
      },
      {
        label: "Strongest Weekday",
        value: bento.strongest_weekday?.label ?? "—",
        caption: bento.strongest_weekday
          ? `${bento.strongest_weekday.hours}h logged`
          : "",
      },
    ];
    highlightCells.forEach((cell, i) => {
      const col = i % 2;
      const row = Math.floor(i / 2);
      const x = rightX + cardPad + col * (subW + subGap);
      const y = subTop + row * (subH + subGap);
      this.#drawBentoCard(ctx, x, y, subW, subH, 16, palette.subcard);

      ctx.fillStyle = palette.muted;
      ctx.font = "500 16px 'Jua', 'Arial Black', sans-serif";
      ctx.fillText(cell.label, x + 22, y + 20);

      ctx.fillStyle = palette.cream;
      ctx.font = "bold 36px 'Jua', 'Arial Black', sans-serif";
      // Scale value down if it overflows the sub-card
      let valueSize = 36;
      ctx.font = `bold ${valueSize}px 'Jua', 'Arial Black', sans-serif`;
      while (ctx.measureText(cell.value).width > subW - 44 && valueSize > 18) {
        valueSize -= 2;
        ctx.font = `bold ${valueSize}px 'Jua', 'Arial Black', sans-serif`;
      }
      ctx.fillText(cell.value, x + 22, y + subH / 2 + 8);

      if (cell.caption) {
        ctx.fillStyle = palette.muted;
        ctx.font = "500 14px 'Jua', 'Arial Black', sans-serif";
        ctx.fillText(cell.caption, x + 22, y + subH - 22);
      }
    });

    const link = document.createElement("a");
    link.download = "flavortown-wrapped.png";
    link.href = canvas.toDataURL("image/png");
    link.click();
  }

  // ─── Bento drawing primitives ─────────────────────────────────────

  #drawBentoCard(ctx, x, y, w, h, r, fill) {
    this.#roundRect(ctx, x, y, w, h, r);
    ctx.fillStyle = fill;
    ctx.fill();
  }

  #drawDonut(ctx, cx, cy, outerRadius, innerRadius, topSource, palette) {
    const slices = topSource?.breakdown?.length
      ? topSource.breakdown
      : [{ label: "—", amount: 1 }];
    const total = slices.reduce((sum, slice) => sum + slice.amount, 0) || 1;

    let angle = -Math.PI / 2;
    slices.forEach((slice, i) => {
      const sweep = (slice.amount / total) * Math.PI * 2;
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.arc(cx, cy, outerRadius, angle, angle + sweep);
      ctx.closePath();
      ctx.fillStyle = palette.donut[i % palette.donut.length];
      ctx.fill();
      angle += sweep;
    });

    // Punch the centre hole
    ctx.beginPath();
    ctx.arc(cx, cy, innerRadius, 0, Math.PI * 2);
    ctx.fillStyle = palette.subcard;
    ctx.fill();

    // Percentage label of the top source
    if (topSource?.percent != null) {
      ctx.fillStyle = palette.cream;
      ctx.font = "bold 36px 'Jua', 'Arial Black', sans-serif";
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText(`${topSource.percent}%`, cx, cy);
      ctx.textAlign = "left";
      ctx.textBaseline = "top";
    }
  }

  #drawHeatmap(ctx, x, y, w, h, buckets, palette) {
    if (!buckets || buckets.length === 0) return;

    const cols = 14;
    const rows = Math.ceil(buckets.length / cols);
    const cellGap = 6;
    const cellSize = Math.min(
      (w - cellGap * (cols - 1)) / cols,
      (h - cellGap * (rows - 1)) / rows,
    );
    const maxValue = Math.max(...buckets, 1);

    buckets.forEach((value, i) => {
      const col = i % cols;
      const row = Math.floor(i / cols);
      const cellX = x + col * (cellSize + cellGap);
      const cellY = y + row * (cellSize + cellGap);
      // Map activity intensity to alpha against the gold accent.
      const intensity = value === 0 ? 0.08 : 0.25 + (value / maxValue) * 0.75;
      ctx.fillStyle = `hsla(36, 70%, 56%, ${intensity})`;
      this.#roundRect(ctx, cellX, cellY, cellSize, cellSize, 4);
      ctx.fill();
    });
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
