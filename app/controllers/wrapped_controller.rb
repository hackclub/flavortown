class WrappedController < ApplicationController
  before_action :require_login
  before_action :check_wrapped_flag

  def show
    @wrapped = WrappedPresenter.new(current_user)
  end

  private

  def require_login
    redirect_to root_path, alert: "Please sign in to view your wrapped." unless current_user
  end

  def check_wrapped_flag
    render_not_found unless Flipper.enabled?(:wrapped, current_user)
  end
end
