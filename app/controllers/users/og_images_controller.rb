class Users::OgImagesController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_user

  def show
    skip_authorization

    png_data = OgImage::User.new(@user).to_png

    expires_in 1.hour, public: true
    send_data png_data, type: "image/png", disposition: "inline"
  end

  private

  def set_user
    @user = User.find(params[:user_id])
  end
end
