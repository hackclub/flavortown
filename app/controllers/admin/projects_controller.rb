class Admin::ProjectsController < Admin::ApplicationController
    PER_PAGE = 25
    include Pundit::Authorization
    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
    before_action :authenticate_admin
    def index
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
      def user_not_authorized
        flash[:alert] = "You are not authorized to perform this action."
        redirect_to(request.referrer || root_path)
      end
end
