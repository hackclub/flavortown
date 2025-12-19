class LandingController < ApplicationController
  def index
    @prizes = Cache::CarouselPrizesJob.fetch
  end
end
