class KitchenController < ApplicationController
  def index
    redirect_to root_path unless current_user
    return unless current_user

    @has_hackatime_linked = current_user.has_hackatime?
    @has_identity_linked = current_user.has_identity_linked?
  end
end
