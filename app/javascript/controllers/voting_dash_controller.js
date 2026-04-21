import { Controller } from "@hotwired/stimulus";
import Chart from "chart.js/auto";

export default class extends Controller {
  static values = {
    dailyLabels: Array,
    dailyValues: Array,
    hourlyLabels: Array,
    hourlyValues: Array,
    qualityByWindow: Object,
  };

  connect() {
    this._onBlessedClick = (e) => this.handleVerdictListClick(e, "blessed");
    this._onCursedClick = (e) => this.handleVerdictListClick(e, "cursed");
    this.setupTrendChart();
    this.bindVerdictLists();
  }

  disconnect() {
    if (this.trendChart) this.trendChart.destroy();
    this.trendChart = null;
    if (this.verdictChart) this.verdictChart.destroy();
    this.verdictChart = null;

    const blessed = this.element.querySelector("#blessed-user-list");
    if (blessed && this._boundBlessed)
      blessed.removeEventListener("click", this._onBlessedClick);
    const cursed = this.element.querySelector("#cursed-user-list");
    if (cursed && this._boundCursed)
      cursed.removeEventListener("click", this._onCursedClick);
    this._boundBlessed = this._boundCursed = false;

    const selectEl = this.element.querySelector("#voteQualityRange");
    if (selectEl && this._onRangeChange) {
      selectEl.removeEventListener("change", this._onRangeChange);
    }
  }

  setupTrendChart() {
    const canvas = this.element.querySelector("#voteQualityTrendChart");
    if (!canvas) return;

    const selectEl = this.element.querySelector("#voteQualityRange");
    const currentAvgEl = this.element.querySelector("#votingCurrentAvg");

    const dailyLabels = this.dailyLabelsValue || [];
    const dailyValues = this.dailyValuesValue || [];
    const hourlyLabels = this.hourlyLabelsValue || [];
    const hourlyValues = this.hourlyValuesValue || [];
    const qualityByWindow = this.qualityByWindowValue || {};

    const trim = (labels, values) => {
      const vals = values || [];
      const idx = vals.findIndex((v) => v != null);
      return idx > 0
        ? { labels: (labels || []).slice(idx), values: vals.slice(idx) }
        : { labels: labels || [], values: vals };
    };

    const seriesFor = (period) => {
      if (period === "24h") return trim(hourlyLabels, hourlyValues);
      const days = { "1w": 7, "1m": 30 }[period];
      if (!days) return trim(dailyLabels, dailyValues);
      const n = Math.min(days, dailyLabels.length);
      const start = Math.max(0, dailyLabels.length - n);
      return trim(dailyLabels.slice(start), dailyValues.slice(start));
    };

    const makeGradient = (el) => {
      const g = el.getContext("2d").createLinearGradient(0, 0, 0, el.height);
      g.addColorStop(0, "rgba(37, 99, 235, 0.18)");
      g.addColorStop(1, "rgba(37, 99, 235, 0.02)");
      return g;
    };

    const updateCurrentAvgDisplay = (per) => {
      if (!currentAvgEl) return;
      const v = qualityByWindow && qualityByWindow[per];
      if (!Number.isFinite(Number(v))) {
        currentAvgEl.textContent = "—";
        return;
      }
      currentAvgEl.textContent = Number(v).toFixed(3);
    };

    const initialPeriod = selectEl ? selectEl.value : "all";
    const initial = seriesFor(initialPeriod);

    const existing = Chart.getChart(canvas);
    if (existing) existing.destroy();
    if (this.trendChart) this.trendChart.destroy();

    this.trendChart = new Chart(canvas, {
      type: "line",
      data: {
        labels: initial.labels,
        datasets: [
          {
            label: "Avg Vote Quality",
            data: initial.values,
            borderColor: "#2563eb",
            backgroundColor: makeGradient(canvas),
            fill: true,
            pointRadius: 2.5,
            pointHoverRadius: 4,
            tension: 0.35,
            borderWidth: 2,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: { duration: 300 },
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: (ctx) => {
                const v = ctx.raw;
                if (v === null || v === undefined) return "—";
                return "Avg: " + Number(v).toFixed(3);
              },
            },
          },
        },
        scales: {
          x: { grid: { display: false } },
          y: {
            beginAtZero: false,
            min: -1,
            max: 1,
            ticks: { callback: (v) => Number(v).toFixed(2) },
            grid: { color: "rgba(0,0,0,0.06)" },
          },
        },
      },
    });

    updateCurrentAvgDisplay(initialPeriod);

    if (selectEl) {
      this._onRangeChange = (e) => {
        const p = e.target.value;
        const next = seriesFor(p);
        const inst = this.trendChart;
        if (inst) {
          inst.data.labels = next.labels;
          inst.data.datasets[0].data = next.values;
          inst.update();
        }
        updateCurrentAvgDisplay(p);
      };
      selectEl.addEventListener("change", this._onRangeChange);
    }
  }

  bindVerdictLists() {
    const blessed = this.element.querySelector("#blessed-user-list");
    if (blessed && !this._boundBlessed) {
      blessed.addEventListener("click", this._onBlessedClick);
      this._boundBlessed = true;
    }
    const cursed = this.element.querySelector("#cursed-user-list");
    if (cursed && !this._boundCursed) {
      cursed.addEventListener("click", this._onCursedClick);
      this._boundCursed = true;
    }
  }

  handleVerdictListClick(event, type) {
    const btn = event.target.closest("button.verdict-user-list__btn");
    if (!btn) return;
    const listId = type === "cursed" ? "#cursed-user-list" : "#blessed-user-list";
    const list = this.element.querySelector(listId);
    if (list) {
      list.querySelectorAll(".verdict-user-list__btn.is-active").forEach((el) =>
        el.classList.remove("is-active"),
      );
    }
    btn.classList.add("is-active");

    const eventIso = btn.getAttribute("data-event-ts") || "";
    const votesBefore = JSON.parse(
      btn.getAttribute("data-votes-before") || "[]",
    );
    const votesAfter = JSON.parse(btn.getAttribute("data-votes-after") || "[]");
    const user = {
      name: (btn.textContent || "").trim(),
      url: btn.getAttribute("data-user-url") || "",
      avatar: btn.getAttribute("data-user-avatar") || "",
    };
    const containerId =
      type === "cursed"
        ? "cursed-drilldown-content"
        : "blessed-drilldown-content";
    this.drawVerdictChart(containerId, type, votesBefore, votesAfter, eventIso, user);
    this.renderVotes(containerId, votesBefore, votesAfter);
  }

  drawVerdictChart(
    containerId,
    verdictType,
    votesBefore,
    votesAfter,
    eventIso,
    user,
  ) {
    const container = this.element.querySelector(`#${containerId}`);
    if (!container) return;

    const header = container.querySelector(".verdict-user-header");
    if (header && user) {
      const avatarLink = header.querySelector(".verdict-user-header__avatar-link");
      const avatarImg = header.querySelector(".verdict-user-header__avatar");
      const nameLink = header.querySelector(".verdict-user-header__name");
      if (avatarLink) avatarLink.href = user.url || "#";
      if (avatarImg) {
        avatarImg.src = user.avatar || "";
        avatarImg.alt = user.name || "";
      }
      if (nameLink) {
        nameLink.href = user.url || "#";
        nameLink.textContent = user.name || "User";
      }
    }
    const canvas = container.querySelector("canvas");
    if (!canvas) return;

    const toTs = (v) => {
      const raw = v.at_iso || v.at || "";
      const ts = Date.parse(raw);
      return Number.isFinite(ts) ? ts : 0;
    };
    const all = [
      ...(votesBefore || []).map((v) => ({ ...v, _side: "before", _ts: toTs(v) })),
      ...(votesAfter || []).map((v) => ({ ...v, _side: "after", _ts: toTs(v) })),
    ].sort((a, b) => a._ts - b._ts);

    const beforePts = [];
    const afterPts = [];
    const eventTs = Date.parse(eventIso || "");
    let eventIndex = -1;
    for (let i = 0; i < all.length; i++) {
      const v = all[i];
      const y = v.rq_score == null ? null : Number(v.rq_score);
      const pt = {
        x: i,
        y: Number.isFinite(y) ? y : null,
        _label: v.at,
        _reason: v.reason,
      };
      (v._side === "before" ? beforePts : afterPts).push(pt);
      if (eventIndex === -1 && Number.isFinite(eventTs) && v._ts >= eventTs) {
        eventIndex = i;
      }
    }
    if (eventIndex === -1) eventIndex = beforePts.length || Math.floor(all.length / 2);

    const eventLinePlugin = {
      id: "eventLine",
      afterDatasetsDraw: (chart) => {
        const xScale = chart.scales.x;
        const area = chart.chartArea;
        if (!xScale || !area) return;
        const x = xScale.getPixelForValue(eventIndex - 0.5);
        const ctx2 = chart.ctx;
        ctx2.save();
        ctx2.strokeStyle = verdictType === "cursed" ? "#ef4444" : "#10b981";
        ctx2.setLineDash([4, 3]);
        ctx2.lineWidth = 2;
        ctx2.beginPath();
        ctx2.moveTo(x, area.top);
        ctx2.lineTo(x, area.bottom);
        ctx2.stroke();
        ctx2.restore();
      },
    };

    const existingChart = Chart.getChart(canvas);
    if (existingChart) existingChart.destroy();
    if (this.verdictChart) this.verdictChart.destroy();

    this.verdictChart = new Chart(canvas, {
      type: "scatter",
      data: {
        datasets: [
          {
            label: "Before votes",
            data: beforePts,
            borderColor: "#ef4444",
            backgroundColor: "rgba(239, 68, 68, 0.7)",
            showLine: false,
            pointRadius: 3,
          },
          {
            label: "After votes",
            data: afterPts,
            borderColor: "#10b981",
            backgroundColor: "rgba(16, 185, 129, 0.7)",
            showLine: false,
            pointRadius: 3,
          },
        ],
      },
      plugins: [eventLinePlugin],
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: "nearest", intersect: true },
        plugins: {
          legend: { display: true, position: "bottom" },
          tooltip: {
            callbacks: {
              label: (ctx) => {
                const d = ctx.raw || {};
                const y = d.y;
                const t = d._label || "";
                return (
                  ctx.dataset.label +
                  ": " +
                  (y == null ? "—" : Number(y).toFixed(3)) +
                  (t ? " — " + t : "")
                );
              },
            },
          },
        },
        scales: {
          y: {
            min: -1,
            max: 1,
            ticks: { callback: (v) => Number(v).toFixed(2) },
            grid: { color: "rgba(0,0,0,0.06)" },
            title: { display: true, text: "Reason Quality" },
          },
          x: {
            type: "linear",
            suggestedMin: -1,
            suggestedMax: Math.max(1, votesBefore.length + votesAfter.length),
            grid: { display: false },
            ticks: { display: false },
          },
        },
      },
    });
  }

  renderVotes(containerId, votesBefore, votesAfter) {
    const votesId = containerId.indexOf("blessed") !== -1 ? "#blessed-votes" : "#cursed-votes";
    const root = this.element.querySelector(votesId);
    if (!root) return;
    const content = root.querySelector(".verdict-votes__content") || root;
    content.innerHTML = "";

    const votesTable = (title, list) => {
      const section = document.createElement("div");
      const h = document.createElement("h4");
      h.textContent = title;
      h.style.margin = "0.25rem 0";
      section.appendChild(h);
      if (!list || list.length === 0) {
        const p = document.createElement("p");
        p.className = "fraud-stats-error";
        p.textContent = "No votes";
        section.appendChild(p);
        return section;
      }
      const table = document.createElement("table");
      table.className = "table";
      const thead = document.createElement("thead");
      thead.innerHTML =
        "<tr><th>At</th><th>Reason</th><th>RQ</th><th>Orig</th><th>Tech</th><th>Use</th><th>Story</th></tr>";
      table.appendChild(thead);
      const tbody = document.createElement("tbody");
      list.forEach((v) => {
        const tr = document.createElement("tr");
        const reasonFull = (v.reason || "").toString();
        const reason = reasonFull.length > 160 ? reasonFull.slice(0, 160) + "…" : reasonFull;
        const cells = [
          v.at || "",
          reason,
          v.rq_score == null ? "—" : Number(v.rq_score).toFixed(3),
          v.originality || "",
          v.technical || "",
          v.usability || "",
          v.storytelling || "",
        ];
        cells.forEach((text, idx) => {
          const td = document.createElement("td");
          if (idx === 1) {
            td.style.maxWidth = "420px";
            td.style.whiteSpace = "normal";
          }
          td.textContent = text;
          tr.appendChild(td);
        });
        tbody.appendChild(tr);
      });
      table.appendChild(tbody);
      section.appendChild(table);
      return section;
    };

    content.appendChild(votesTable("Before", votesBefore));
    content.appendChild(votesTable("After", votesAfter));
  }
}
