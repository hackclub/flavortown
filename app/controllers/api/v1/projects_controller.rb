class Api::V1::ProjectsController < ApplicationController
  include ApiAuthenticatable

  class_attribute :url_params_model, default: {}
  class_attribute :response_body_model, default: {}

  self.url_params_model = {
    index: {
      page: { type: Integer, desc: "Page number for pagination", required: false }
    }
  }

  self.response_body_model = {
    index: [
      {
        id: Integer,
        title: String,
        description: String,
        repo_url: String,
        demo_url: String,
        readme_url: String,
        created_at: String,
        updated_at: String
      }
    ],

    show: {
      id: Integer,
      title: String,
      description: String,
      repo_url: String,
      demo_url: String,
      readme_url: String,
      created_at: String,
      updated_at: String
    }
  }

  def index
    @pagy, @projects = pagy(Project.where(deleted_at: nil), items: 100)
  end

  def show
    @project = Project.find_by!(id: params[:id], deleted_at: nil)
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Project not found" }, status: :not_found
  end
end
