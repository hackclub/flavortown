class Admin::UsersController < Admin::ApplicationController
    PER_PAGE = 25
    include Pundit::Authorization
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

    def show
      @user = User.find(params[:id])
      @current_user = current_user
    end

    def user_perms
      @users = User.joins(:role_assignments).includes(:roles).distinct.order(:id)
    end

    def promote_role
    @user = User.find(params[:id])
    role_name = params[:role_name]

    role = Role.find_by(name: role_name)

    if role && !@user.roles.include?(role)
    @user.roles << role
    flash[:notice] = "User promoted to #{role_name}."
    else
    flash[:alert] = "Unable to promote user to #{role_name}."
    end

    redirect_to admin_user_path(@user)
    end

  def demote_role
    @user = User.find(params[:id])
    role_name = params[:role_name]

    role = Role.find_by(name: role_name)

    if role && @user.roles.include?(role)
      @user.roles.delete(role)
      flash[:notice] = "User demoted from #{role_name}."
    else
      flash[:alert] = "Unable to demote user from #{role_name}."
    end

    redirect_to admin_user_path(@user)
  end

    def user_not_authorized
      flash[:alert] = "You are not authorized to perform this action."
      redirect_to(request.referrer || root_path)
    end
end
