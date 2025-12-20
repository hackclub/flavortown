class LandingController < ApplicationController
  def index
    @prizes = Cache::CarouselPrizesJob.fetch
    @hide_sidebar = true
  end
end
