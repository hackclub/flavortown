class Api::V1::ProjectsController < ApplicationController
  def index
      @projects = Project.where(deleted_at: nil).page(params[:page]).per(100)
  end

  def show
    @project = Project.find_by!(id: params[:id], deleted_at: nil)
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Project not found" }, status: :not_found
  end
end