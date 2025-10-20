class Admin::UsersController < Admin::ApplicationController
    PER_PAGE = 25
    include Pundit
    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized  
    before_action :authenticate_admin

    def index

        @query = params[:query]
    
        users = if @query.present?
          q = "%#{@query}%"
          User.where("email ILIKE ? OR display_name ILIKE ?", q, q)
        else
          User.all
        end
    
        # Pagination logic
        @page = params[:page].to_i
        @page = 1 if @page < 1
        @total_users = users.count
        @total_pages = (@total_users / PER_PAGE.to_f).ceil
        @users = users.order(:id).offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
      end
      def user_not_authorized
        flash[:alert] = "You are not authorized to perform this action."
        redirect_to(request.referrer || root_path)
      end  
    end
  