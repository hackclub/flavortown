import { Controller } from "@hotwired/stimulus";
import Chart from "chart.js/auto";

export default class extends Controller {
  static targets = ["canvas"];
  static values = { spendingData: Object };

  connect() {
    if (this.hasCanvasTarget && this.hasSpendingDataValue) {
      this.render();
    }
  }

  render() {
    const data = this.spendingDataValue;
    const labels = Object.keys(data);
    const values = Object.values(data);

    if (labels.length === 0 || values.length === 0) {
      return;
    }

    const colors = [
      "#ef4444",
      "#f97316",
      "#eab308",
      "#22c55e",
      "#06b6d4",
      "#0ea5e9",
      "#3b82f6",
      "#8b5cf6",
      "#ec4899",
      "#f43f5e",
      "#6366f1",
      "#a855f7",
      "#d946ef",
      "#db2777",
      "#be185d",
      "#7c2d12",
      "#292524",
      "#64748b",
    ];

    new Chart(this.canvasTarget, {
      type: "doughnut",
      data: {
        labels: labels,
        datasets: [
          {
            data: values,
            backgroundColor: colors.slice(0, labels.length),
            borderColor: "#ffffff",
            borderWidth: 2,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "bottom",
            labels: {
              padding: 15,
              font: { size: 12 },
            },
          },
          tooltip: {
            callbacks: {
              label: (context) => {
                const label = context.label || "";
                const value = context.parsed || 0;
                const total = context.dataset.data.reduce((a, b) => a + b, 0);
                const percentage = ((value / total) * 100).toFixed(1);
                return (
                  label +
                  ": $" +
                  value.toLocaleString("en-US", {
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2,
                  }) +
                  " (" +
                  percentage +
                  "%)"
                );
              },
            },
          },
        },
      },
    });
  }
}
