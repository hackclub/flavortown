class Admin::ProjectsController < Admin::ApplicationController
  def index
    authorize :admin, :manage_projects?
    @query = params[:query]
    @filter = params[:filter] || "active"

    projects = case @filter
    when "deleted"
      Project.unscoped.deleted
    when "all"
      Project.unscoped.all
    else
      Project.all
    end

    if @query.present?
      q = "%#{@query}%"
      projects = projects.where("title ILIKE ? OR description ILIKE ?", q, q)
    end

    @pagy, @projects = pagy(:offset, projects.order(:id))
  end

  def show
    authorize :admin, :manage_projects?
    @project = Project.unscoped.find(params[:id])
  end

  def restore
    authorize :admin, :manage_projects?
    @project = Project.unscoped.find(params[:id])

    if @project.deleted?
      @project.restore!
      redirect_to admin_project_path(@project), notice: "Project restored successfully."
    else
      redirect_to admin_project_path(@project), alert: "Project is not deleted."
    end
  end
end
