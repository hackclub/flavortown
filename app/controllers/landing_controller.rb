class LandingController < ApplicationController
  def index
    if current_user
      redirect_to projects_path
      return
    end

    @current_user = current_user
    @is_admin = current_user&.admin? || false
    @prizes = Cache::CarouselPrizesJob.perform_now || []
    if @prizes.any?
      prize_ids = @prizes.map { |p| p[:id] }
      records_by_id = ShopItem.with_attached_image.where(id: prize_ids).index_by(&:id)
      @prizes = @prizes.map { |p| p.merge(record: records_by_id[p[:id]]) }
    end
  end
end
