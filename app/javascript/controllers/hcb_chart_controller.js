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

    const LABEL_COLORS = {
      Contributor: "#22c55e",
      Expenses: "#ef4444",
      Funding: "#0ea5e9",
      Mail: "#f97316",
      Merch: "#8b5cf6",
      Prize: "#eab308",
      "Pyramid scheme": "#db2777",
      Stickers: "#6366f1",
      Untagged: "#64748b",
    };

    new Chart(this.canvasTarget, {
      type: "doughnut",
      data: {
        labels: labels,
        datasets: [
          {
            data: values,
            backgroundColor: labels.map((label) => LABEL_COLORS[label]),
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
