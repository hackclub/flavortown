class UserProfilesController < ApplicationController
  before_action :require_login
  before_action :set_user
  before_action :set_profile

  def edit
    authorize @user_profile
  end

  def update
    authorize @user_profile

    if @user_profile.update(profile_params)
      redirect_to user_path(@user), notice: "Profile updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find(params[:user_id])
  end

  def set_profile
    @user_profile = @user.user_profile || @user.build_user_profile
  end

  def profile_params
    params.require(:user_profile).permit(:bio, :custom_css)
  end
end
