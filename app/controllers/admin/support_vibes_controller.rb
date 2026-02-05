module Admin
  class SupportVibesController < Admin::ApplicationController
    def index
      authorize :admin, :access_support_vibes?
    end
  end
end