module Helper
  class SupportVibesController < ApplicationController
    def index
      authorize :helper, :view_support_vibes?
      @vibes = SupportVibes.order(period_end: :desc).limit(20)
      @support_vibes_history = @vibes.map { |d| [ d.period_end, d.overall_sentiment ] }
    end
  end
end
