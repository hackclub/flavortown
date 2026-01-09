class Projects::OgImagesController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :set_project

  def show
    skip_authorization

    png_data = OgImage::Project.new(@project).to_png

    expires_in 1.hour, public: true
    send_data png_data, type: "image/png", disposition: "inline"
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end
end
