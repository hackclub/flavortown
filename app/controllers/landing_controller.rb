class LandingController < ApplicationController
  def index
    if current_user
      redirect_to projects_path
      return
    end

    @current_user = current_user
    @is_admin = current_user&.admin? || false
    @prizes = Cache::CarouselPrizesJob.perform_now || []
  end
end
