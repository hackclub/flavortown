class DevSessionsController < ApplicationController
  skip_forgery_protection only: :create
  before_action :ensure_development

  def create
    user = find_or_create_dev_admin
    session[:user_id] = user.id
    redirect_to projects_path, notice: "Signed in as dev admin: #{user.email}"
  end

  private

  def ensure_development
    raise ActionController::RoutingError, "Not Found" unless Rails.env.development?
  end

  def find_or_create_dev_admin
    user = User.find_by(email: "dev@localhost")
    return user if user

    user = User.create!(
      email: "dev@localhost",
      display_name: "Dev Admin",
      slack_id: "DEV#{SecureRandom.hex(4).upcase}"
    )
    user.make_super_admin!
    user
  end
end
