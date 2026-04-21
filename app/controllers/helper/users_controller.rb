module Helper
  class UsersController < ApplicationController
    def index
      authorize :helper, :view_users?
      @q = params[:query]

      u = User.all
      if @q.present?
        q = "%#{ActiveRecord::Base.sanitize_sql_like(@q)}%"
        u = u.where("display_name ILIKE ? OR email ILIKE ? OR slack_id ILIKE ?", q, q, q)
      end

      @pagy, @users = pagy(:offset, u.order(:id))
    end

    def show
      authorize :helper, :view_users?
      @user = User.includes(:identities, :projects, :vote_verdict).find(params[:id])
    end

    def balance
      authorize :helper, :view_users?
      return head :bad_request unless turbo_frame_request?

      @user = User.find(params[:id])
      @balance = @user.ledger_entries.includes(:ledgerable).order(created_at: :desc)

      render "helper/users/balance"
    end
  end
end
