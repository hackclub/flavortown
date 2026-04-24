# frozen_string_literal: true

module Admin
  module SuperMegaDashboardHelper
    PAYOUT_FILTERS = {
      "Last 24 Hours" => "24h",
      "Last Week" => "week",
      "Last Month" => "month",
      "All Time" => "all"
    }.freeze

    def payout_options
      PAYOUT_FILTERS
    end

    def selected_payout_options
      params[:filter_period].presence || "all"
    end

    def payout_period_select
      { "payout-dash-target": "periodSelect", action: "change->payout-dash#updatePeriod" }
    end
  end
end
