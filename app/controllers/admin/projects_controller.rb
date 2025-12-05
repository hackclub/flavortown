class Admin::ProjectsController < Admin::ApplicationController
  def index
    authorize :admin, :manage_projects?
    @query = params[:query]

    projects = if @query.present?
      q = "%#{@query}%"
      Project.where("title ILIKE ? OR description ILIKE ?", q, q)
    else
      Project.all
    end

    @pagy, @projects = pagy(:offset, projects.order(:id))
  end
end
