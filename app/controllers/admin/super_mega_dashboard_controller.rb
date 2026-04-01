# frozen_string_literal: true

module Admin
  class SuperMegaDashboardController < Admin::ApplicationController
    include SuperMegaDashboard::FraudStats
    include SuperMegaDashboard::FulfillmentStats
    include SuperMegaDashboard::SupportStats
    include SuperMegaDashboard::ShipwrightsStats
    include SuperMegaDashboard::YswsReviewStats
    include SuperMegaDashboard::MiscStats

    CACHE_KEYS = %w[
      super_mega_fraud_stats
      super_mega_ban_trend
      super_mega_order_trend
      super_mega_report_trend
      joe_fraud_stats
      super_mega_payouts
      super_mega_fulfillment
      super_mega_fulfillment_trend
      super_mega_order_states_trend
      super_mega_support
      super_mega_support_vibes
      super_mega_support_graph
      super_mega_voting
      super_mega_sidequests
      super_mega_ysws_review_v2
      super_mega_ship_certs_raw
      sw_vibes_data
      super_mega_funnel_stats
      super_mega_nps_stats
      super_mega_hcb_stats
    ].freeze

    SECTIONS = {
      "funnel"             => { loaders: %i[load_funnel_stats] },
      "nps"                => { loaders: %i[load_nps_stats] },
      "hcb"                => { loaders: %i[load_hcb_expenses] },
      "fraud"              => { loaders: %i[load_fraud_stats load_fraud_happiness_data] },
      "payouts"            => { loaders: %i[load_payouts_stats] },
      "fulfillment"        => { loaders: %i[load_fulfillment_stats] },
      "shipwrights"        => { loaders: %i[load_ship_certs_stats load_sw_vibes_stats load_sw_vibes_history] },
      "support"            => { loaders: %i[load_support_stats load_support_vibes_stats load_support_graph_data] },
      "ysws_review"        => { loaders: %i[load_ysws_review_stats] },
      "voting"             => { loaders: %i[load_voting_stats] },
      "community"          => { loaders: %i[load_community_engagement_stats] },
      "pyramid_flavortime" => { loaders: %i[load_flavortime_summary load_pyramid_scheme_stats] },
      "sidequests"         => { loaders: %i[load_sidequest_stats] }
    }.freeze

    def index
      authorize :admin, :access_super_mega_dashboard?
    end

    def load_section
      authorize :admin, :access_super_mega_dashboard?

      section = params[:section]
      config = SECTIONS[section]

      unless config
        render plain: "Unknown section", status: :bad_request
        return
      end

      config[:loaders].each { |loader| send(loader) }
      render partial: "admin/super_mega_dashboard/sections/#{section}", layout: false
    end

    def clear_cache
      authorize :admin, :access_super_mega_dashboard?

      CACHE_KEYS.each { |key| Rails.cache.delete(key) }

      flash[:notice] = "Cache cleared successfully."
      redirect_to admin_super_mega_dashboard_path
    end
  end
end
