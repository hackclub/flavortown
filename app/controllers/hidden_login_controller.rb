class HiddenLoginController < ApplicationController
  def index
    if current_user
      redirect_to kitchen_path
    else
      render :index
    end
  end
end
