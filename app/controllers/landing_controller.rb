class LandingController < ApplicationController
  def index
    @prizes = Cache::CarouselPrizesJob.perform_now
  end
end
