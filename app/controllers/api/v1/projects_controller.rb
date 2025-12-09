class Api::V1::ProjectsController < ApplicationController
  include ApiAuthenticatable

  def index
    @pagy, @projects = pagy(Project.where(deleted_at: nil), items: 100)
  end

  def show
    @project = Project.find_by!(id: params[:id], deleted_at: nil)
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Project not found" }, status: :not_found
  end
end
