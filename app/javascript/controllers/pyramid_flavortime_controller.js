import { Controller } from "@hotwired/stimulus";
import Chart from "chart.js/auto";
import ChartDataLabels from "chartjs-plugin-datalabels";

export default class extends Controller {
  static targets = [
    "pyramidActivityChart",
    "pyramidActivityRange",
    "pyramidReferralChart",
    "pyramidPosterChart",
    "flavortimeActivityChart",
  ];

  static values = {
    pyramidActivityTimeline: Array,
    pyramidReferralChart: Object,
    pyramidPosterChart: Object,
    flavortimeActivityChart: Object,
  };

  connect() {
    this._charts = [];
    this._pyramidActivityChart = null;

    if (this._canRenderPyramidCharts()) {
      this._renderPyramidCharts();
    }

    if (this._canRenderFlavortimeChart()) {
      this._renderFlavortimeChart();
    }
  }

  disconnect() {
    this._charts.forEach((chart) => chart.destroy());
    this._charts = [];
    this._pyramidActivityChart = null;
  }

  pyramidRangeChanged() {
    if (!this._pyramidActivityChart || !this.hasPyramidActivityTimelineValue)
      return;

    this._pyramidActivityChart.data = this._buildPyramidActivityChartData(
      this._sliceTimelineByRange(this.pyramidActivityTimelineValue),
    );
    this._pyramidActivityChart.update();
  }

  _canRenderPyramidCharts() {
    return (
      this.hasPyramidActivityChartTarget &&
      this.hasPyramidActivityRangeTarget &&
      this.hasPyramidReferralChartTarget &&
      this.hasPyramidPosterChartTarget &&
      this.hasPyramidActivityTimelineValue &&
      this.hasPyramidReferralChartValue &&
      this.hasPyramidPosterChartValue
    );
  }

  _canRenderFlavortimeChart() {
    return (
      this.hasFlavortimeActivityChartTarget &&
      this.hasFlavortimeActivityChartValue
    );
  }

  _renderPyramidCharts() {
    const activityTimeline = this.pyramidActivityTimelineValue;
    const referralData = this.pyramidReferralChartValue;
    const posterData = this.pyramidPosterChartValue;

    this._pyramidActivityChart = new Chart(this.pyramidActivityChartTarget, {
      data: this._buildPyramidActivityChartData(
        this._sliceTimelineByRange(activityTimeline),
      ),
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: "index",
          intersect: false,
        },
        plugins: {
          legend: {
            position: "bottom",
          },
          tooltip: {
            callbacks: {
              label: (context) => {
                if (context.dataset.label === "Verified Hours") {
                  return `${context.dataset.label}: ${context.parsed.y}h`;
                }

                return `${context.dataset.label}: ${context.parsed.y}`;
              },
            },
          },
        },
        scales: {
          x: {
            ticks: {
              font: { size: 11 },
              autoSkip: true,
              maxTicksLimit: 10,
              maxRotation: 0,
            },
          },
          y: {
            beginAtZero: true,
            ticks: {
              precision: 0,
            },
            title: {
              display: true,
              text: "Users / referrals",
            },
          },
          y1: {
            beginAtZero: true,
            position: "right",
            grid: {
              drawOnChartArea: false,
            },
            title: {
              display: true,
              text: "Verified hours",
            },
          },
        },
      },
    });
    this._charts.push(this._pyramidActivityChart);

    const referralChart = new Chart(this.pyramidReferralChartTarget, {
      type: "doughnut",
      data: {
        labels: referralData.labels,
        datasets: [
          {
            data: referralData.values,
            backgroundColor: ["#f59e0b", "#3b82f6", "#10b981"],
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: "58%",
        plugins: {
          legend: {
            position: "bottom",
          },
        },
      },
    });
    this._charts.push(referralChart);

    const posterChart = new Chart(this.pyramidPosterChartTarget, {
      type: "pie",
      data: {
        labels: posterData.labels,
        datasets: [
          {
            data: posterData.values,
            backgroundColor: ["#10b981", "#3b82f6", "#ef4444"],
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "bottom",
          },
          datalabels: {
            color: "#111827",
            font: {
              weight: "600",
            },
            formatter(value) {
              return value > 0 ? value : "";
            },
          },
        },
      },
      plugins: [ChartDataLabels],
    });
    this._charts.push(posterChart);
  }

  _renderFlavortimeChart() {
    const activityData = this.flavortimeActivityChartValue;

    const flavortimeChart = new Chart(this.flavortimeActivityChartTarget, {
      data: {
        labels: activityData.labels,
        datasets: [
          {
            type: "bar",
            label: "Sessions",
            data: activityData.sessions,
            backgroundColor: "rgba(59, 130, 246, 0.75)",
            borderRadius: 8,
            yAxisID: "y",
          },
          {
            type: "line",
            label: "Status Hours",
            data: activityData.status_hours,
            borderColor: "#f59e0b",
            backgroundColor: "rgba(245, 158, 11, 0.2)",
            tension: 0.35,
            fill: false,
            yAxisID: "y1",
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: "index",
          intersect: false,
        },
        plugins: {
          legend: {
            position: "bottom",
          },
        },
        scales: {
          x: {
            ticks: { font: { size: 11 } },
          },
          y: {
            beginAtZero: true,
            title: {
              display: true,
              text: "Sessions",
            },
          },
          y1: {
            beginAtZero: true,
            position: "right",
            grid: {
              drawOnChartArea: false,
            },
            title: {
              display: true,
              text: "Status Hours",
            },
          },
        },
      },
    });

    this._charts.push(flavortimeChart);
  }

  _sliceTimelineByRange(timeline) {
    if (!Array.isArray(timeline)) return [];
    if (!this.hasPyramidActivityRangeTarget) return timeline;
    if (this.pyramidActivityRangeTarget.value === "all") return timeline;

    const now = new Date();
    const cutoffByRange = {
      "1w": new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000),
      "4w": new Date(now.getTime() - 28 * 24 * 60 * 60 * 1000),
      "8w": new Date(now.getTime() - 56 * 24 * 60 * 60 * 1000),
      "12w": new Date(now.getTime() - 84 * 24 * 60 * 60 * 1000),
    };

    const cutoff = cutoffByRange[this.pyramidActivityRangeTarget.value];
    if (!cutoff) return timeline;

    return timeline.filter((entry) => new Date(entry.date) >= cutoff);
  }

  _formatDate(value) {
    return new Date(value).toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
    });
  }

  _formatWeekLabel(value) {
    return `Week of ${this._formatDate(value)}`;
  }

  _startOfWeek(value) {
    const date = new Date(value);
    const day = date.getDay();
    const offset = (day + 6) % 7;
    date.setDate(date.getDate() - offset);
    date.setHours(0, 0, 0, 0);
    return date;
  }

  _bucketTimelineByWeek(timeline) {
    const buckets = new Map();

    timeline.forEach((entry) => {
      const weekStart = this._startOfWeek(entry.date).toISOString();
      if (!buckets.has(weekStart)) {
        buckets.set(weekStart, {
          date: weekStart,
          users_added: 0,
          referrals_completed: 0,
          verified_hours: 0,
          posters_approved: 0,
        });
      }

      const bucket = buckets.get(weekStart);
      bucket.users_added += entry.users_added || 0;
      bucket.referrals_completed += entry.referrals_completed || 0;
      bucket.verified_hours += entry.verified_hours || 0;
      bucket.posters_approved += entry.posters_approved || 0;
    });

    return Array.from(buckets.values()).sort(
      (left, right) => new Date(left.date) - new Date(right.date),
    );
  }

  _buildPyramidActivityChartData(timeline) {
    const weeklyTimeline = this._bucketTimelineByWeek(timeline);

    return {
      labels: weeklyTimeline.map((entry) => this._formatWeekLabel(entry.date)),
      datasets: [
        {
          type: "bar",
          label: "Users Added",
          data: weeklyTimeline.map((entry) => entry.users_added),
          backgroundColor: "rgba(59, 130, 246, 0.78)",
          borderColor: "#2563eb",
          borderWidth: 1,
          borderRadius: 10,
          maxBarThickness: 34,
          yAxisID: "y",
        },
        {
          type: "bar",
          label: "Completed Referrals",
          data: weeklyTimeline.map((entry) => entry.referrals_completed),
          backgroundColor: "rgba(16, 185, 129, 0.68)",
          borderColor: "#059669",
          borderWidth: 1,
          borderRadius: 10,
          maxBarThickness: 34,
          yAxisID: "y",
        },
        {
          type: "line",
          label: "Verified Hours",
          data: weeklyTimeline.map((entry) =>
            Number(entry.verified_hours.toFixed(1)),
          ),
          borderColor: "#f59e0b",
          backgroundColor: "rgba(245, 158, 11, 0.16)",
          borderWidth: 3,
          pointRadius: 3,
          pointHoverRadius: 5,
          tension: 0.28,
          fill: true,
          yAxisID: "y1",
        },
      ],
    };
  }
}
