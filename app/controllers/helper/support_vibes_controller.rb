module Helper
  class SupportVibesController < ApplicationController
    def index
      authorize :helper, :view_support_vibes?
      @vibes = SupportVibes.order(period_end: :desc).limit(20)
    end
  end
end
