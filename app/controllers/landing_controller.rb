class LandingController < ApplicationController
  def index
    if current_user
      steps_left = User::TutorialStep.all.count - current_user.tutorial_steps.count
      if steps_left > 0
        redirect_to kitchen_path
        return
      else
        redirect_to projects_path
        return
      end
    end
    @prizes = Cache::CarouselPrizesJob.perform_now || []
    if @prizes.any?
      prize_ids = @prizes.map { |p| p[:id] }
      records_by_id = ShopItem.with_attached_image.where(id: prize_ids).index_by(&:id)
      @prizes = @prizes.map { |p| p.merge(record: records_by_id[p[:id]]) }
    end
  end
end
