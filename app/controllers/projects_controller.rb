class ProjectsController < ApplicationController
  before_action :set_project_minimal, only: [ :edit, :update, :destroy ]
  before_action :set_project, only: [ :show, :readme ]

  def index
    authorize Project
    @projects = current_user.projects.includes(banner_attachment: :blob)
  end

  def show
    authorize @project
    @posts = @project
      .posts
      .order(created_at: :desc)
      .includes(:user, postable: [ { attachments_attachments: :blob } ])
  end

  def readme
    authorize @project

    unless turbo_frame_request?
      redirect_to project_path(@project)
      return
    end

    url = @project.readme_url

    if url.present?
      begin
        require "net/http"
        uri = URI(url)
        response = Net::HTTP.get_response(uri)
        content = response.is_a?(Net::HTTPSuccess) ? response.body.force_encoding("UTF-8") : "Failed to load README from #{url}"
      rescue => e
        content = "Error loading README: #{e.message}"
      end
    else
      content = "Couldn't find README! Make sure ya set it up!"
    end

    @html = MarkdownRenderer.render(content)
    render layout: false
  end

  def new
    @project = Project.new
    authorize @project
  end

  def create
    @project = Project.new(project_params)
    authorize @project

    validate_hackatime_projects

    if @project.errors.empty? && @project.save
      # Create membership for the current user as owner
      @project.memberships.create!(user: current_user, role: :owner)
      link_hackatime_projects
      flash[:notice] = "Project created successfully"
      redirect_to @project
    else
      flash[:alert] = "Failed to create project: #{@project.errors.full_messages.join(', ')}"
      render :new, status: :unprocessable_entity
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
      flash[:alert] = "Failed to update project: #{@project.errors.full_messages.join(', ')}"
      render :edit, status: :unprocessable_entity
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

  def hackatime_project_ids
    @hackatime_project_ids ||= Array(params[:project][:hackatime_project_ids]).reject(&:blank?)
  end

  def validate_hackatime_projects
    return if hackatime_project_ids.empty?

    already_linked = current_user.hackatime_projects
                                 .where(id: hackatime_project_ids)
                                 .where.not(project_id: nil)

    return unless already_linked.any?

    @project.errors.add(:base, "The following Hackatime projects are already linked: #{already_linked.pluck(:name).join(', ')}")
  end

  def link_hackatime_projects
    return if hackatime_project_ids.empty?

    current_user.hackatime_projects.where(id: hackatime_project_ids).find_each do |hp|
      hp.update!(project: @project)
    end
  end
end
