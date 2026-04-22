import { Controller } from "@hotwired/stimulus";
import * as d3 from "d3";

function safeJsonParse(value, fallback) {
  if (!value) return fallback;
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
}

function clearSvgs(container) {
  container.querySelectorAll("svg").forEach((el) => el.remove());
}

export default class extends Controller {
  connect() {
    this.queueRender = this.queueRender.bind(this);
    this._resizeHandler = this.queueRender;
    window.addEventListener("resize", this._resizeHandler);
    this._rafHandle = null;
    this.queueRender();
  }

  disconnect() {
    window.removeEventListener("resize", this._resizeHandler);
    if (this._rafHandle) {
      cancelAnimationFrame(this._rafHandle);
      this._rafHandle = null;
    }
  }

  openModal(event) {
    const modalId = event.currentTarget.dataset.modalId || event.params.modalId;
    if (!modalId) return;
    const modal = document.getElementById(modalId);
    if (!modal) return;
    modal.style.display = "flex";
    this.queueRender();
  }

  closeModal(event) {
    const modalId = event.currentTarget.dataset.modalId || event.params.modalId;
    if (!modalId) return;
    const modal = document.getElementById(modalId);
    if (!modal) return;
    modal.style.display = "none";
  }

  backdropClose(event) {
    if (event.target !== event.currentTarget) return;
    if (!(event.currentTarget instanceof HTMLElement)) return;
    event.currentTarget.style.display = "none";
  }

  queueRender() {
    if (this._rafHandle) return;
    this._rafHandle = requestAnimationFrame(() => {
      this._rafHandle = null;
      this.renderVibesTrend();
      this.renderJoeUnresolved();
      this.renderBanTrend();
      this.renderReportTrend();
    });
  }

  renderVibesTrend() {
    const container = this.element.querySelector("#vibesTrendContainer");
    if (!container) return;
    if (container.clientWidth <= 0) return;

    const raw = safeJsonParse(container.dataset.fraudDashVibesHistory, null);
    if (!raw) return;

    const sortedWeeks = Object.keys(raw).sort();
    const tableData = sortedWeeks.map((week) => ({
      week,
      avg_feeling: raw[week]?.avg_feeling || 0,
      avg_shop: raw[week]?.avg_shop || 0,
      avg_reports: raw[week]?.avg_reports || 0,
    }));

    const seriesConfig = [
      { key: "avg_feeling", label: "Overall", color: "#10b981" },
      { key: "avg_shop", label: "Shop Orders", color: "#3b82f6" },
      { key: "avg_reports", label: "Reports", color: "#f59e0b" },
    ];

    const tooltip = this.element.querySelector("#vibesTrendTooltip");
    const legendEl = this.element.querySelector("#vibesTrendLegend");
    if (!tooltip || !legendEl) return;

    const margin = { top: 10, right: 10, bottom: 20, left: 30 };
    const height = 140;

    legendEl.innerHTML = seriesConfig
      .map(
        (cfg) =>
          `<span><span class="d3-stream-legend__swatch" style="background:${cfg.color}"></span>${cfg.label}</span>`,
      )
      .join("");

    clearSvgs(container);

    const width = container.clientWidth;
    const innerW = width - margin.left - margin.right;
    const innerH = height - margin.top - margin.bottom;

    const svg = d3
      .select(container)
      .append("svg")
      .attr("width", width)
      .attr("height", height);
    const g = svg
      .append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`);

    const x = d3
      .scalePoint()
      .domain(sortedWeeks)
      .range([0, innerW])
      .padding(0.2);

    const allValues = tableData.flatMap((d) =>
      seriesConfig.map((cfg) => d[cfg.key]).filter((value) => value > 0),
    );

    const yMin = Math.max(0, (d3.min(allValues) ?? 0) - 1);
    const yMax = Math.min(10, (d3.max(allValues) ?? 0) + 1);

    const y = d3.scaleLinear().domain([yMin, yMax]).range([innerH, 0]);

    g.append("g")
      .attr("class", "d3-stream-grid")
      .call(
        d3.axisLeft(y).ticks(5).tickSize(-innerW).tickFormat(d3.format("d")),
      )
      .selectAll("text")
      .style("font-size", "7px");

    const tickEvery = Math.ceil(sortedWeeks.length / 6);
    g.append("g")
      .attr("transform", `translate(0,${innerH})`)
      .call(
        d3
          .axisBottom(x)
          .tickValues(sortedWeeks.filter((_, idx) => idx % tickEvery === 0)),
      )
      .selectAll("text")
      .style("font-size", "7px")
      .attr("transform", "rotate(-30)")
      .attr("text-anchor", "end");

    const lineGen = d3
      .line()
      .x((d) => x(d.week))
      .curve(d3.curveMonotoneX);

    seriesConfig.forEach((cfg) => {
      g.append("path")
        .datum(tableData)
        .attr("fill", "none")
        .attr("stroke", cfg.color)
        .attr("stroke-width", 1.5)
        .attr(
          "d",
          lineGen.y((d) => y(d[cfg.key])),
        );

      g.selectAll(`.dot-${cfg.key}`)
        .data(tableData.filter((d) => d[cfg.key] > 0))
        .join("circle")
        .attr("cx", (d) => x(d.week))
        .attr("cy", (d) => y(d[cfg.key]))
        .attr("r", 2)
        .attr("fill", cfg.color)
        .attr("stroke", "#fff")
        .attr("stroke-width", 1);
    });

    const crosshair = g
      .append("line")
      .attr("y1", 0)
      .attr("y2", innerH)
      .attr("stroke", "#94a3b8")
      .attr("stroke-width", 1)
      .attr("stroke-dasharray", "4,3")
      .attr("pointer-events", "none")
      .style("display", "none");

    svg
      .append("rect")
      .attr("transform", `translate(${margin.left},${margin.top})`)
      .attr("width", innerW)
      .attr("height", innerH)
      .attr("fill", "none")
      .attr("pointer-events", "all")
      .on("mousemove", (event) => {
        const mx = d3.pointer(event, event.currentTarget)[0];

        const closest = sortedWeeks.reduce((a, b) =>
          Math.abs(x(a) - mx) < Math.abs(x(b) - mx) ? a : b,
        );
        const pt = tableData.find((d) => d.week === closest);
        if (!pt) return;

        crosshair
          .attr("x1", x(closest))
          .attr("x2", x(closest))
          .style("display", null);

        tooltip.className = "d3-stream-tooltip is-visible";
        tooltip.innerHTML = `<strong>${closest}</strong><br>${seriesConfig
          .map(
            (cfg) =>
              `<span style="color:${cfg.color}">${cfg.label}: ${pt[cfg.key] || "N/A"}</span>`,
          )
          .join("<br>")}`;
        var ttW = tooltip.offsetWidth || 0;
        var desiredLeft = x(closest) + margin.left + 10;
        var maxLeft = margin.left + innerW - ttW - 2;
        var clampedLeft = Math.max(margin.left, Math.min(desiredLeft, maxLeft));
        tooltip.style.left = clampedLeft + "px";
        tooltip.style.top = `${margin.top}px`;
      })
      .on("mouseleave", () => {
        crosshair.style("display", "none");
        tooltip.className = "d3-stream-tooltip";
      });
  }

  renderJoeUnresolved() {
    const container = this.element.querySelector("#joeUnresolvedContainer");
    if (!container) return;
    if (container.clientWidth <= 0) return;

    const createdOverTime = safeJsonParse(
      container.dataset.fraudDashJoeCreatedOverTime,
      null,
    );

    if (!createdOverTime || createdOverTime.length === 0) return;

    const avgHangTime = parseFloat(
      container.dataset.fraudDashJoeAvgHangTimeDays,
    );
    const openCount = parseInt(container.dataset.fraudDashJoeOpenCount, 10);
    const waitingCount = parseInt(
      container.dataset.fraudDashJoeWaitingCount,
      10,
    );

    const tooltip = this.element.querySelector("#joeUnresolvedTooltip");
    const legendEl = this.element.querySelector("#joeUnresolvedLegend");
    if (!tooltip || !legendEl) return;

    const tableData = createdOverTime.map((d) => ({
      date: new Date(d.bucket),
      created: d.count,
    }));

    const margin = { top: 10, right: 50, bottom: 20, left: 30 };
    const height = 140;

    legendEl.innerHTML = [
      '<span><span class="d3-stream-legend__swatch" style="background:#f59e0b"></span>Cases Created/Week</span>',
      '<span><span class="d3-stream-legend__swatch" style="background:#ef4444"></span>Avg Hang Time (days)</span>',
    ].join("");

    clearSvgs(container);

    const width = container.clientWidth;
    const innerW = width - margin.left - margin.right;
    const innerH = height - margin.top - margin.bottom;

    const svg = d3
      .select(container)
      .append("svg")
      .attr("width", width)
      .attr("height", height);
    const g = svg
      .append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`);

    const x = d3
      .scaleTime()
      .domain(d3.extent(tableData, (d) => d.date))
      .range([0, innerW]);

    const yLeft = d3
      .scaleLinear()
      .domain([0, d3.max(tableData, (d) => d.created) * 1.2])
      .range([innerH, 0]);

    const yRight = d3
      .scaleLinear()
      .domain([0, avgHangTime * 1.5])
      .range([innerH, 0]);

    g.append("g")
      .attr("class", "d3-stream-grid")
      .call(
        d3
          .axisLeft(yLeft)
          .ticks(4)
          .tickSize(-innerW)
          .tickFormat(d3.format("d")),
      )
      .selectAll("text")
      .style("font-size", "7px");

    g.append("g")
      .attr("transform", `translate(${innerW},0)`)
      .call(
        d3
          .axisRight(yRight)
          .ticks(4)
          .tickFormat((d) => `${d}d`),
      )
      .selectAll("text")
      .style("font-size", "7px");

    g.append("g")
      .attr("transform", `translate(0,${innerH})`)
      .call(
        d3
          .axisBottom(x)
          .ticks(tableData.length)
          .tickFormat(d3.timeFormat("%b %d")),
      )
      .selectAll("text")
      .style("font-size", "7px");

    const barWidth = Math.max(2, (innerW / tableData.length) * 0.4);
    g.selectAll(".bar")
      .data(tableData)
      .join("rect")
      .attr("class", "bar")
      .attr("x", (d) => x(d.date) - barWidth / 2)
      .attr("y", (d) => yLeft(d.created))
      .attr("width", barWidth)
      .attr("height", (d) => innerH - yLeft(d.created))
      .attr("fill", "#f59e0b")
      .attr("opacity", 0.7);

    g.append("line")
      .attr("x1", 0)
      .attr("x2", innerW)
      .attr("y1", yRight(avgHangTime))
      .attr("y2", yRight(avgHangTime))
      .attr("stroke", "#ef4444")
      .attr("stroke-width", 1.5)
      .attr("stroke-dasharray", "4,3");

    g.append("text")
      .attr("x", innerW - 2)
      .attr("y", yRight(avgHangTime) - 3)
      .attr("text-anchor", "end")
      .attr("fill", "#ef4444")
      .style("font-size", "7px")
      .text(`${avgHangTime}d avg`);

    const lastPoint = tableData[tableData.length - 1];
    g.append("circle")
      .attr("cx", x(lastPoint.date))
      .attr("cy", yLeft(openCount + waitingCount))
      .attr("r", 4)
      .attr("fill", "#ef4444")
      .attr("stroke", "#fff")
      .attr("stroke-width", 1);

    svg
      .append("rect")
      .attr("transform", `translate(${margin.left},${margin.top})`)
      .attr("width", innerW)
      .attr("height", innerH)
      .attr("fill", "none")
      .attr("pointer-events", "all")
      .on("mousemove", (event) => {
        const mx = d3.pointer(event, event.currentTarget)[0];
        const bisect = d3.bisector((d) => d.date).left;
        const x0 = x.invert(mx);
        const idx = Math.min(bisect(tableData, x0), tableData.length - 1);
        const pt = tableData[idx];

        tooltip.className = "d3-stream-tooltip is-visible";
        tooltip.innerHTML =
          `<strong>${d3.timeFormat("%b %d")(pt.date)}</strong><br>` +
          `<span style="color:#f59e0b">Created: ${pt.created}</span><br>` +
          `<span style="color:#ef4444">Avg hang: ${avgHangTime}d</span>`;
        var ttW = tooltip.offsetWidth || 0;
        var desiredLeft = x(pt.date) + margin.left + 10;
        var maxLeft = margin.left + innerW - ttW - 2;
        var clampedLeft = Math.max(margin.left, Math.min(desiredLeft, maxLeft));
        tooltip.style.left = clampedLeft + "px";
        tooltip.style.top = `${margin.top}px`;
      })
      .on("mouseleave", () => {
        tooltip.className = "d3-stream-tooltip";
      });
  }

  renderBanTrend() {
    const container = this.element.querySelector("#banTrendContainer");
    if (!container) return;
    if (container.clientWidth <= 0) return;

    const raw = safeJsonParse(container.dataset.fraudDashBanTrend, null);
    if (!raw) return;

    const sortedDates = Object.keys(raw).sort();
    const tableData = sortedDates.map((dateKey) => ({
      date: new Date(dateKey),
      bans: raw[dateKey]?.bans,
      unbans: raw[dateKey]?.unbans,
      shadow_bans: raw[dateKey]?.shadow_bans || 0,
    }));

    const seriesConfig = [
      { key: "bans", label: "Bans", color: "#ef4444" },
      { key: "unbans", label: "Unbans", color: "#10b981" },
      { key: "shadow_bans", label: "Shadow Bans", color: "#8b5cf6" },
    ];

    const tooltip = this.element.querySelector("#banTrendTooltip");
    const legendEl = this.element.querySelector("#banTrendLegend");
    if (!tooltip || !legendEl) return;

    const margin = { top: 10, right: 10, bottom: 20, left: 30 };
    const height = 140;

    legendEl.innerHTML = seriesConfig
      .map(
        (cfg) =>
          `<span><span class="d3-stream-legend__swatch" style="background:${cfg.color}"></span>${cfg.label}</span>`,
      )
      .join("");

    const keys = seriesConfig.map((c) => c.key);
    const colorMap = {};
    seriesConfig.forEach((c) => {
      colorMap[c.key] = c.color;
    });

    const stack = d3
      .stack()
      .keys(keys)
      .order(d3.stackOrderInsideOut)
      .offset(d3.stackOffsetWiggle);

    const stackedData = stack(tableData);

    clearSvgs(container);

    const width = container.clientWidth;
    const innerW = width - margin.left - margin.right;
    const innerH = height - margin.top - margin.bottom;

    const svg = d3
      .select(container)
      .append("svg")
      .attr("width", width)
      .attr("height", height);

    const g = svg
      .append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`);

    const x = d3
      .scaleTime()
      .domain(d3.extent(tableData, (d) => d.date))
      .range([0, innerW]);

    const yExtent = [
      d3.min(stackedData, (layer) => d3.min(layer, (d) => d[0])),
      d3.max(stackedData, (layer) => d3.max(layer, (d) => d[1])),
    ];

    const y = d3.scaleLinear().domain(yExtent).range([innerH, 0]);

    const area = d3
      .area()
      .x((d) => x(d.data.date))
      .y0((d) => y(d[0]))
      .y1((d) => y(d[1]))
      .curve(d3.curveCatmullRom);

    g.append("g")
      .attr("transform", `translate(0,${innerH})`)
      .call(
        d3
          .axisBottom(x)
          .ticks(Math.min(sortedDates.length, 8))
          .tickFormat(d3.timeFormat("%b %d")),
      )
      .selectAll("text")
      .style("font-size", "7px");

    g.selectAll(".stream-layer")
      .data(stackedData)
      .join("path")
      .attr("class", "stream-layer")
      .attr("d", area)
      .attr("fill", (d) => colorMap[d.key])
      .attr("opacity", 0.8);

    const crosshair = g
      .append("line")
      .attr("y1", 0)
      .attr("y2", innerH)
      .attr("stroke", "#94a3b8")
      .attr("stroke-width", 1)
      .attr("stroke-dasharray", "4,3")
      .attr("pointer-events", "none")
      .style("display", "none");

    svg
      .append("rect")
      .attr("transform", `translate(${margin.left},${margin.top})`)
      .attr("width", innerW)
      .attr("height", innerH)
      .attr("fill", "none")
      .attr("pointer-events", "all")
      .on("mousemove", (event) => {
        const mx = d3.pointer(event, event.currentTarget)[0];
        const bisect = d3.bisector((d) => d.date).left;
        const x0 = x.invert(mx);
        const idx = bisect(tableData, x0, 1);
        const d0 = tableData[idx - 1];
        const d1 = tableData[idx];
        const pt = !d1 || x0 - d0.date < d1.date - x0 ? d0 : d1;

        crosshair
          .attr("x1", x(pt.date))
          .attr("x2", x(pt.date))
          .style("display", null);

        tooltip.className = "d3-stream-tooltip is-visible";
        tooltip.innerHTML = `<strong>${d3.timeFormat("%b %d")(pt.date)}</strong><br>${seriesConfig
          .map(
            (cfg) =>
              `<span style="color:${cfg.color}">${cfg.label}: ${pt[cfg.key]}</span>`,
          )
          .join("<br>")}`;
        var ttW = tooltip.offsetWidth || 0;
        var desiredLeft = x(pt.date) + margin.left + 10;
        var maxLeft = margin.left + innerW - ttW - 2;
        var clampedLeft = Math.max(margin.left, Math.min(desiredLeft, maxLeft));
        tooltip.style.left = clampedLeft + "px";
        tooltip.style.top = `${margin.top}px`;
      })
      .on("mouseleave", () => {
        crosshair.style("display", "none");
        tooltip.className = "d3-stream-tooltip";
      });
  }

  renderReportTrend() {
    const container = this.element.querySelector("#reportTrendContainer");
    if (!container) return;
    if (container.clientWidth <= 0) return;

    const raw = safeJsonParse(container.dataset.fraudDashReportTrend, null);
    if (!raw) return;

    const sortedDates = Object.keys(raw).sort();

    const reasonColors = {
      low_effort: "#f59e0b",
      undeclared_ai: "#ef4444",
      demo_broken: "#3b82f6",
      stolen_code: "#8b5cf6",
      inappropriate: "#ec4899",
      other: "#6366f1",
    };

    const defaultColor = "#10b981";

    const reasonSet = {};
    sortedDates.forEach((dateKey) => {
      Object.keys(raw[dateKey] || {}).forEach((reason) => {
        reasonSet[reason] = true;
      });
    });

    const reasons = Object.keys(reasonSet);

    const tableData = sortedDates.map((dateKey) => {
      const row = { date: new Date(dateKey) };
      reasons.forEach((reason) => {
        row[reason] = (raw[dateKey] || {})[reason] || 0;
      });
      return row;
    });

    const seriesConfig = reasons.map((reason) => ({
      key: reason,
      label: reason
        .replace(/_/g, " ")
        .replace(/\b\w/g, (letter) => letter.toUpperCase()),
      color: reasonColors[reason] || defaultColor,
    }));

    const tooltip = this.element.querySelector("#reportTrendTooltip");
    const legendEl = this.element.querySelector("#reportTrendLegend");
    if (!tooltip || !legendEl) return;

    const margin = { top: 10, right: 10, bottom: 20, left: 30 };
    const height = 140;

    legendEl.innerHTML = seriesConfig
      .map(
        (cfg) =>
          `<span><span class="d3-stream-legend__swatch" style="background:${cfg.color}"></span>${cfg.label}</span>`,
      )
      .join("");

    clearSvgs(container);

    const width = container.clientWidth;
    const innerW = width - margin.left - margin.right;
    const innerH = height - margin.top - margin.bottom;

    const svg = d3
      .select(container)
      .append("svg")
      .attr("width", width)
      .attr("height", height);
    const g = svg
      .append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`);

    const x = d3
      .scaleTime()
      .domain(d3.extent(tableData, (d) => d.date))
      .range([0, innerW]);

    const yMax =
      d3.max(tableData, (d) => d3.max(reasons, (reason) => d[reason])) || 1;

    const y = d3
      .scaleLinear()
      .domain([0, yMax * 1.1])
      .range([innerH, 0]);

    g.append("g")
      .attr("class", "d3-stream-grid")
      .call(
        d3.axisLeft(y).ticks(4).tickSize(-innerW).tickFormat(d3.format("d")),
      )
      .selectAll("text")
      .style("font-size", "7px");

    g.append("g")
      .attr("transform", `translate(0,${innerH})`)
      .call(
        d3
          .axisBottom(x)
          .ticks(Math.min(sortedDates.length, 8))
          .tickFormat(d3.timeFormat("%b %d")),
      )
      .selectAll("text")
      .style("font-size", "7px");

    const lineGen = d3
      .line()
      .x((d) => x(d.date))
      .curve(d3.curveMonotoneX);

    seriesConfig.forEach((cfg) => {
      g.append("path")
        .datum(tableData)
        .attr("fill", "none")
        .attr("stroke", cfg.color)
        .attr("stroke-width", 1.5)
        .attr(
          "d",
          lineGen.y((d) => y(d[cfg.key])),
        );

      g.selectAll(`.dot-${cfg.key}`)
        .data(tableData)
        .join("circle")
        .attr("cx", (d) => x(d.date))
        .attr("cy", (d) => y(d[cfg.key]))
        .attr("r", 2)
        .attr("fill", cfg.color)
        .attr("stroke", "#fff")
        .attr("stroke-width", 1);
    });

    const crosshair = g
      .append("line")
      .attr("y1", 0)
      .attr("y2", innerH)
      .attr("stroke", "#94a3b8")
      .attr("stroke-width", 1)
      .attr("stroke-dasharray", "4,3")
      .attr("pointer-events", "none")
      .style("display", "none");

    svg
      .append("rect")
      .attr("transform", `translate(${margin.left},${margin.top})`)
      .attr("width", innerW)
      .attr("height", innerH)
      .attr("fill", "none")
      .attr("pointer-events", "all")
      .on("mousemove", (event) => {
        const mx = d3.pointer(event, event.currentTarget)[0];
        const bisect = d3.bisector((d) => d.date).left;
        const x0 = x.invert(mx);
        const idx = bisect(tableData, x0, 1);
        const d0 = tableData[idx - 1];
        const d1 = tableData[idx];
        const pt = !d1 || x0 - d0.date < d1.date - x0 ? d0 : d1;

        crosshair
          .attr("x1", x(pt.date))
          .attr("x2", x(pt.date))
          .style("display", null);

        tooltip.className = "d3-stream-tooltip is-visible";
        tooltip.innerHTML = `<strong>${d3.timeFormat("%b %d")(pt.date)}</strong><br>${seriesConfig
          .map(
            (cfg) =>
              `<span style="color:${cfg.color}">${cfg.label}: ${pt[cfg.key]}</span>`,
          )
          .join("<br>")}`;
        var ttW = tooltip.offsetWidth || 0;
        var desiredLeft = x(pt.date) + margin.left + 10;
        var maxLeft = margin.left + innerW - ttW - 2;
        var clampedLeft = Math.max(margin.left, Math.min(desiredLeft, maxLeft));
        tooltip.style.left = clampedLeft + "px";
        tooltip.style.top = `${margin.top}px`;
      })
      .on("mouseleave", () => {
        crosshair.style("display", "none");
        tooltip.className = "d3-stream-tooltip";
      });
  }
}
