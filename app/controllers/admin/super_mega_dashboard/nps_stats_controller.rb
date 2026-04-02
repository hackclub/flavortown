# frozen_string_literal: true

module Admin
  module SuperMegaDashboard
    class NpsStatsController < Admin::ApplicationController
      include NpsStats

      def refresh_vibes
        authorize :admin, :access_super_mega_dashboard?

        Rails.cache.delete("super_mega_nps_vibes")
        payload = build_nps_vibes_from_airtable(limit: 500)

        Rails.cache.write("super_mega_nps_vibes", payload)
        if payload.is_a?(Hash) && payload[:error].present?
          flash[:alert] = payload[:error]
        else
          flash[:notice] = "NPS vibes revibed."
        end
        
        redirect_to admin_super_mega_dashboard_path
      end
    end
  end
end
