class Api::V1::UsersController < Api::BaseController
  include ApiAuthenticatable

  def index
    users = User.includes(:projects).all

    if params[:query].present?
      # TODO: if search becomes slow for any reason, add pg_trgm GIN index for ILIKE performance
      q = "%#{ActiveRecord::Base.sanitize_sql_like(params[:query])}%"
      users = users.where("display_name ILIKE :q OR slack_id ILIKE :q", q: q)
    end

    limit = params.fetch(:limit, 100).to_i
    return render json: { error: "Limit must be between 1 and 100" }, status: :bad_request if limit < 1 || limit > 100

    @pagy, @users = pagy(users, page: params[:page], limit: limit)
  end

  def show
    @user = params[:id] == "me" ? current_api_user : User.find(params[:id])
    ActiveRecord::Associations::Preloader.new(records: [ @user ], associations: :ledger_entries).call if @user.leaderboard_optin?
  end
end
