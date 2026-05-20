module Helper
  class UsersController < ApplicationController
    ALLOWED_FLIPPER_FEATURES = %i[vote_balance_override shop_orders].freeze

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

    def toggle_flipper
      authorize :helper, :toggle_flipper?

      @user = User.find(params[:id])
      feature = params[:feature].to_sym

      unless ALLOWED_FLIPPER_FEATURES.include?(feature)
        return redirect_to helper_user_path(@user), alert: "Unknown feature."
      end

      if @user.helper? || @user.admin? || @user.fraud_dept? || @user == current_user
        return redirect_to helper_user_path(@user), alert: "Cannot modify flags for staff users."
      end
      if Flipper.enabled?(feature, @user)
        Flipper.disable(feature, @user)
        PaperTrail::Version.create!(
          item_type: "User",
          item_id: @user.id,
          event: "flipper_disable",
          whodunnit: current_user.id,
          object_changes: { feature: [ feature.to_s, nil ], status: [ "enabled", "disabled" ] }.to_json
        )
        flash[:notice] = "Disabled #{feature} for #{@user.display_name}."
      else
        Flipper.enable(feature, @user)
        PaperTrail::Version.create!(
          item_type: "User",
          item_id: @user.id,
          event: "flipper_enable",
          whodunnit: current_user.id,
          object_changes: { feature: [ nil, feature.to_s ], status: [ "disabled", "enabled" ] }.to_json
        )
        flash[:notice] = "Enabled #{feature} for #{@user.display_name}."
      end

      redirect_to helper_user_path(@user)
    end
  end
end
