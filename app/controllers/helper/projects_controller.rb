module Helper
  class ProjectsController < ApplicationController
    def index
      authorize :helper, :view_projects?
      @q = params[:query]

      p = Project.all
      if @q.present?
        q = "%#{@q}%"
        p = p.where("title ILIKE ? OR description ILIKE ?", q, q)
      end

      @pagy, @projects = pagy(:offset, p.order(:id))
    end

    def show
      authorize :helper, :view_projects?
      @project = Project.find(params[:id])
    end
  end
end
