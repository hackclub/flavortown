class LandingController < ApplicationController
  def index
    if current_user
      redirect_to projects_path
      return
    end

    @prizes = Cache::CarouselPrizesJob.perform_now
  end
end
