class ProjectsController < ApplicationController
  before_action :set_project_minimal, only: [ :edit, :update, :destroy ]
  before_action :set_project, only: [ :show ]

  def index
    @projects = current_user.projects.with_attached_banner

    authorize Project
  end

  def show
    authorize @project
  end

  def new
    @project = Project.new
    authorize @project
  end

  def create
    @project = Project.new(project_params)
    authorize @project

    if @project.save
      # Create membership for the current user as owner
      @project.memberships.create!(user: current_user, role: :owner)
      flash[:notice] = "Project created successfully"
      redirect_to @project
    else
      flash[:alert] = "Failed to create project"
      render :new
    end
  end

  def edit
    authorize @project
  end

  def update
    authorize @project

    if @project.update(project_params)
      flash[:notice] = "Project updated successfully"
      redirect_to @project
    else
      flash[:alert] = "Failed to update project"
      render :edit
    end
  end

  def destroy
    authorize @project
    @project.destroy
    flash[:notice] = "Project deleted successfully"
    redirect_to projects_path
  end

  private

  # These are the same today, but they'll be different tomorrow.

  def set_project
    @project = Project.find(params[:id])
  end

  def set_project_minimal
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:title, :description, :demo_url, :repo_url, :readme_url, :banner)
  end
end
