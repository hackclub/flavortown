module Helper
  class UsersController < ApplicationController
    def index
      authorize :helper, :view_users?
      @q = params[:query]

      u = User.all
      if @q.present?
        q = "%#{@q}%"
        u = u.where("display_name ILIKE ?", q)
      end

      @pagy, @users = pagy(:offset, u.order(:id))
    end

    def show
      authorize :helper, :view_users?
      @user = User.includes(:identities, :projects).find(params[:id])
    end
  end
end
