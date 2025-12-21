class LandingController < ApplicationController
  def index
    @prizes = Cache::CarouselPrizesJob.fetch
    @hide_sidebar = true

    def index
      if current_user
        redirect_to kitchen_path
      else
        render :index
      end
    end
  end
end
