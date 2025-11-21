class Admin::ProjectsController < Admin::ApplicationController
    PER_PAGE = 25
    def index
        authorize :admin, :manage_projects?
        @query = params[:query]

        projects = if @query.present?
          q = "%#{@query}%"
          Project.where("title ILIKE ? OR description ILIKE ?", q, q)
        else
          Project.all
        end

        # Pagination logic
        @page = params[:page].to_i
        @page = 1 if @page < 1
        @total_projects = projects.count
        @total_pages = (@total_projects / PER_PAGE.to_f).ceil
        @projects = projects.order(:id).offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
      end
end
