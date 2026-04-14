import { Controller } from "@hotwired/stimulus";
import * as d3 from "d3";

const DEFAULT_WIDTH = 960;
const FUNNEL_HEIGHT = 420;
const MARGIN = { top: 32, right: 16, bottom: 24, left: 16 };
const MIN_CHART_INNER_WIDTH = 540;
const MIN_STEP_WIDTH = 150;
const MAX_BAND_HEIGHT_RATIO = 0.9;
const TOOLTIP_PADDING = 16;

const GRADIENT_STOPS = [
  { offset: "0%", color: "#4c6fff" },
  { offset: "100%", color: "#93c5fd" },
];

function normalizeSteps(steps) {
  return (Array.isArray(steps) ? steps : []).map((step) => {
    const rawName = String(step?.name || "");
    return {
      key: rawName,
      value: parseInt(step?.count, 10) || 0,
    };
  });
}

function anyNonZero(data) {
  return data.some((d) => d.value > 0);
}

function computeLayout({ containerWidth, stepCount }) {
  const baseInnerWidth = containerWidth - MARGIN.left - MARGIN.right;
  const innerHeight = FUNNEL_HEIGHT - MARGIN.top - MARGIN.bottom;
  const centerY = innerHeight / 2;
  const maxBandHeight = innerHeight * MAX_BAND_HEIGHT_RATIO;

  let chartInnerWidth = Math.max(baseInnerWidth, MIN_CHART_INNER_WIDTH);
  let stepWidth = chartInnerWidth / stepCount;

  if (stepWidth < MIN_STEP_WIDTH) {
    stepWidth = MIN_STEP_WIDTH;
    chartInnerWidth = stepWidth * stepCount;
  }

  const bandWidth = stepWidth;
  const width = chartInnerWidth + MARGIN.left + MARGIN.right;

  return {
    width,
    height: FUNNEL_HEIGHT,
    margin: MARGIN,
    innerHeight,
    centerY,
    maxBandHeight,
    bandWidth,
    stepCount,
  };
}

function computeStepPoints({ data, bandWidth, maxBandHeight, maxValue }) {
  return data.map((d, index) => {
    const bandHeight = maxBandHeight * (d.value / maxValue);
    const x = (index + 0.5) * bandWidth;
    return { ...d, x, bandHeight };
  });
}

function computeBoundaryHeights(points) {
  if (points.length === 0) return [];

  const boundaryHeights = [];
  for (let i = 0; i <= points.length; i += 1) {
    if (i === 0) {
      boundaryHeights.push(points[0].bandHeight);
    } else if (i === points.length) {
      boundaryHeights.push(points[points.length - 1].bandHeight);
    } else {
      boundaryHeights.push(
        (points[i - 1].bandHeight + points[i].bandHeight) / 2,
      );
    }
  }

  return boundaryHeights;
}

function buildFunnelOutlinePoints({
  boundaryHeights,
  stepCount,
  bandWidth,
  centerY,
}) {
  const topPoints = [];
  const bottomPoints = [];

  for (let i = 0; i <= stepCount; i += 1) {
    const x = i * bandWidth;
    const bandHeight = boundaryHeights[i] ?? 0;
    topPoints.push([x, centerY - bandHeight / 2]);
  }
  for (let i = stepCount; i >= 0; i -= 1) {
    const x = i * bandWidth;
    const bandHeight = boundaryHeights[i] ?? 0;
    bottomPoints.push([x, centerY + bandHeight / 2]);
  }

  return topPoints.concat(bottomPoints);
}

function buildLinearPath(points) {
  if (!points.length) return "";
  const [first, ...rest] = points;
  const moveTo = `M${first[0]},${first[1]}`;
  const lineTos = rest.map((d) => `L${d[0]},${d[1]}`).join(" ");
  return `${moveTo} ${lineTos} Z`;
}

function createSvg({ width, height }) {
  return d3
    .create("svg")
    .attr("viewBox", `0 0 ${width} ${height}`)
    .attr("width", "100%")
    .attr("preserveAspectRatio", "xMidYMid meet")
    .style("display", "block");
}

function appendGradient(svg, gradientId) {
  const defs = svg.append("defs");
  const gradient = defs
    .append("linearGradient")
    .attr("id", gradientId)
    .attr("x1", "0%")
    .attr("y1", "0%")
    .attr("x2", "100%")
    .attr("y2", "0%");

  GRADIENT_STOPS.forEach((stop) => {
    gradient
      .append("stop")
      .attr("offset", stop.offset)
      .attr("stop-color", stop.color);
  });
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function formatPercent(value) {
  return `${(value * 100).toFixed(1)}%`;
}

function formatDelta(value) {
  const sign = value > 0 ? "+" : "";
  return `${sign}${(value * 100).toFixed(1)}%`;
}

function tooltipMarkup({
  stepKey,
  currentValue,
  retentionFromPrevious,
  changeVsPrevious,
  retainedFromFirst,
  isFirstStep,
}) {
  return `
    <div class="d3-funnel-tooltip__step">Step: <span>${escapeHtml(stepKey)}</span></div>
    <div class="d3-funnel-tooltip__count">Count: ${currentValue.toLocaleString()}</div>
    <hr />
    <div class="d3-funnel-tooltip__row">
      <span>Retained</span>
      <span>${formatPercent(retentionFromPrevious)}</span>
    </div>
    <div class="d3-funnel-tooltip__row">
      <span>Compared to previous</span>
      <span>${isFirstStep ? "—" : formatDelta(changeVsPrevious)}</span>
    </div>
    <div class="d3-funnel-tooltip__row d3-funnel-tooltip__row--muted">
      <span>From first step</span>
      <span>${formatPercent(retainedFromFirst)}</span>
    </div>
  `;
}

function showTooltip(tooltip) {
  tooltip.style.display = "block";
  tooltip.style.opacity = "1";
  tooltip.setAttribute("aria-hidden", "false");
}

function hideTooltip(tooltip) {
  tooltip.style.display = "none";
  tooltip.style.opacity = "0";
  tooltip.setAttribute("aria-hidden", "true");
}

function positionTooltip({ tooltip, event }) {
  const viewportWidth =
    window.innerWidth || document.documentElement.clientWidth;
  const viewportHeight =
    window.innerHeight || document.documentElement.clientHeight;

  const rect = tooltip.getBoundingClientRect();

  let left = event.clientX + TOOLTIP_PADDING;
  let top = event.clientY - rect.height / 2;

  if (left + rect.width + TOOLTIP_PADDING > viewportWidth) {
    left = event.clientX - rect.width - TOOLTIP_PADDING;
  }
  if (top < TOOLTIP_PADDING) {
    top = TOOLTIP_PADDING;
  } else if (top + rect.height + TOOLTIP_PADDING > viewportHeight) {
    top = viewportHeight - rect.height - TOOLTIP_PADDING;
  }
  tooltip.style.left = `${left + window.scrollX}px`;
  tooltip.style.top = `${top + window.scrollY}px`;
}

export default class extends Controller {
  static targets = ["chart", "tooltip"];
  static values = { steps: Array };

  connect() {
    this.gradientId = `funnelGradient-${crypto.randomUUID()}`;
    this.render();
  }

  disconnect() {
    if (this.tooltipElement) {
      this.tooltipElement.remove();
      this.tooltipElement = null;
    }
  }

  render() {
    const rawSteps = this.stepsValue;

    if (!Array.isArray(rawSteps) || rawSteps.length === 0) {
      console.warn("[Funnel] No data available");
      return;
    }

    const data = normalizeSteps(rawSteps);
    if (data.length === 0) {
      console.warn("[Funnel] No data available");
      return;
    }

    if (!anyNonZero(data)) {
      console.error("[Funnel] All values are zero");
      return;
    }

    const container = this.hasChartTarget ? this.chartTarget : null;
    const tooltip = this.hasTooltipTarget ? this.tooltipTarget : null;
    if (!container) {
      console.error("[Funnel] Container not found");
      return;
    }

    if (tooltip && tooltip.parentElement !== document.body) {
      document.body.appendChild(tooltip);
    }
    this.tooltipElement = tooltip;

    try {
      const stepCount = data.length;
      const containerWidth = container.clientWidth || DEFAULT_WIDTH;
      const layout = computeLayout({ containerWidth, stepCount });

      const maxValue = d3.max(data, (d) => d.value) || 1;
      const points = computeStepPoints({
        data,
        bandWidth: layout.bandWidth,
        maxBandHeight: layout.maxBandHeight,
        maxValue,
      });

      const boundaryHeights = computeBoundaryHeights(points);
      const outlinePoints = buildFunnelOutlinePoints({
        boundaryHeights,
        stepCount: layout.stepCount,
        bandWidth: layout.bandWidth,
        centerY: layout.centerY,
      });

      const pathData = buildLinearPath(outlinePoints);
      const svg = createSvg({ width: layout.width, height: layout.height });
      appendGradient(svg, this.gradientId);

      const g = svg
        .append("g")
        .attr(
          "transform",
          `translate(${layout.margin.left},${layout.margin.top})`,
        );

      g.append("path")
        .attr("d", pathData)
        .attr("fill", `url(#${this.gradientId})`)
        .attr("fill-opacity", 0.9);

      g.append("path")
        .attr("d", pathData)
        .attr("fill", "none")
        .attr("stroke", "var(--color-brown-700)")
        .attr("stroke-width", 1)
        .attr("stroke-opacity", 0.9);

      const separatorGroup = g.append("g");
      const sectionTop = layout.centerY - layout.maxBandHeight / 2 - 16;
      const sectionBottom = layout.centerY + layout.maxBandHeight / 2 + 16;
      for (let i = 0; i <= layout.stepCount; i += 1) {
        const x = i * layout.bandWidth;
        separatorGroup
          .append("line")
          .attr("x1", x)
          .attr("y1", sectionTop)
          .attr("x2", x)
          .attr("y2", sectionBottom)
          .attr("stroke", "var(--color-brown-500)")
          .attr("stroke-width", 1)
          .attr("stroke-opacity", 0.9);
      }

      const overlay = g.append("g");
      const firstValue = data[0].value || 0;

      points.forEach((point, index) => {
        const currentValue = point.value;
        const prevValue =
          index === 0 ? currentValue : points[index - 1].value || currentValue;

        const retentionFromPrevious =
          index === 0 ? 1 : prevValue === 0 ? 0 : currentValue / prevValue;
        const changeVsPrevious =
          index === 0
            ? 0
            : prevValue === 0
              ? 0
              : (currentValue - prevValue) / prevValue;

        const bandLeft = index * layout.bandWidth;
        const bandCenter = bandLeft + layout.bandWidth / 2;

        overlay
          .append("rect")
          .attr("x", bandLeft)
          .attr("y", layout.centerY - layout.maxBandHeight / 2 - 16)
          .attr("width", layout.bandWidth)
          .attr("height", layout.maxBandHeight + 32)
          .attr("fill", "transparent")
          .on("mousemove", (event) => {
            if (!tooltip) return;

            const retainedFromFirst =
              firstValue === 0 ? 0 : currentValue / firstValue;
            tooltip.innerHTML = tooltipMarkup({
              stepKey: point.key,
              currentValue,
              retentionFromPrevious,
              changeVsPrevious,
              retainedFromFirst,
              isFirstStep: index === 0,
            });

            showTooltip(tooltip);
            positionTooltip({ tooltip, event });
          })
          .on("mouseleave", () => {
            if (!tooltip) return;
            hideTooltip(tooltip);
          });

        g.append("text")
          .attr("class", "d3-funnel-label d3-funnel-label--step")
          .attr("x", bandCenter)
          .attr("y", layout.centerY - layout.maxBandHeight / 2 - 12)
          .attr("text-anchor", "middle")
          .text(point.key);

        g.append("text")
          .attr("class", "d3-funnel-label d3-funnel-label--metric")
          .attr("x", bandCenter)
          .attr("y", layout.centerY + layout.maxBandHeight / 2 + 20)
          .attr("text-anchor", "middle")
          .text(
            `${currentValue.toLocaleString()} · ${formatPercent(
              firstValue === 0 ? 0 : currentValue / firstValue,
            )}`,
          );
      });

      const leftLabelGroup = svg
        .append("g")
        .attr(
          "transform",
          `translate(24,${layout.margin.top + layout.centerY})`,
        );

      leftLabelGroup
        .append("text")
        .attr("class", "d3-funnel-total-label")
        .attr("x", 0)
        .attr("y", -6)
        .text(firstValue.toLocaleString());

      leftLabelGroup
        .append("text")
        .attr("class", "d3-funnel-total-subtitle")
        .attr("x", 0)
        .attr("y", 14)
        .text("Count");

      container.innerHTML = "";
      container.appendChild(svg.node());
    } catch (error) {
      console.error("[Funnel] Chart rendering failed:", error);
    }
  }
}
