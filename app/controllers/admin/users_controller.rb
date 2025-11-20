class Admin::UsersController < Admin::ApplicationController
    PER_PAGE = 25
    include Pundit::Authorization
    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
    before_action :authenticate_admin
    skip_before_action :authenticate_admin, only: [ :stop_impersonating ]

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

      # Get role assignment history from audit logs
      all_role_versions = PaperTrail::Version
        .where(item_type: "User::RoleAssignment")
        .order(created_at: :desc)
        .limit(100)

      # Filter to only this user's role changes
      @role_history = all_role_versions.select do |v|
        changes = YAML.load(v.object_changes) rescue {}
        user_id_change = changes["user_id"]
        user_id_change.is_a?(Array) ? user_id_change.include?(@user.id) : user_id_change == @user.id
      end.take(20)

      # Get all actions performed on this user
      @user_actions = PaperTrail::Version
        .where(item_type: "User", item_id: @user.id)
        .order(created_at: :desc)
        .limit(50)
    end

    def user_perms
      @users = User.joins(:role_assignments).includes(:roles).distinct.order(:id)
    end

    def promote_role
      unless current_user.super_admin?
        flash[:alert] = "Only super admins can manage user roles."
        return redirect_to admin_user_path(params[:id])
      end

      @user = User.find(params[:id])
      role_name = params[:role_name]

      if role_name == "Super_Admin"
        flash[:alert] = "Only super admins can promote to super admin."
        return redirect_to admin_user_path(@user)
      end

      role = Role.find_by(name: role_name)

      if role && !@user.roles.include?(role)
        PaperTrail.request(whodunnit: current_user.id) do
          @user.roles << role
        end
        flash[:notice] = "User promoted to #{role_name}."
      else
        flash[:alert] = "Unable to promote user to #{role_name}."
      end

      redirect_to admin_user_path(@user)
    end

  def demote_role
    unless current_user.super_admin?
      flash[:alert] = "Only super admins can manage user roles."
      return redirect_to admin_user_path(params[:id])
    end

    @user = User.find(params[:id])
    role_name = params[:role_name]

    if role_name == "Super_Admin"
      flash[:alert] = "Only super admins can demote super admin."
      return redirect_to admin_user_path(@user)
    end

    role = Role.find_by(name: role_name)

    if role && @user.roles.include?(role)
      PaperTrail.request(whodunnit: current_user.id) do
        @user.roles.delete(role)
      end
      flash[:notice] = "User demoted from #{role_name}."
    else
      flash[:alert] = "Unable to demote user from #{role_name}."
    end

    redirect_to admin_user_path(@user)
  end

  def toggle_flipper
    unless current_user.admin?
      flash[:alert] = "Only admins can toggle features."
      return redirect_to admin_user_path(params[:id])
    end

    @user = User.find(params[:id])
    feature = params[:feature].to_sym

    if Flipper.enabled?(feature, @user)
      Flipper.disable(feature, @user)
      PaperTrail::Version.create!(
        item_type: "User",
        item_id: @user.id,
        event: "flipper_disable",
        whodunnit: current_user.id,
        object_changes: { feature: [ feature.to_s, nil ], status: [ "enabled", "disabled" ] }.to_yaml
      )
      flash[:notice] = "Disabled #{feature} for #{@user.display_name}."
    else
      Flipper.enable(feature, @user)
      PaperTrail::Version.create!(
        item_type: "User",
        item_id: @user.id,
        event: "flipper_enable",
        whodunnit: current_user.id,
        object_changes: { feature: [ nil, feature.to_s ], status: [ "disabled", "enabled" ] }.to_yaml
      )
      flash[:notice] = "Enabled #{feature} for #{@user.display_name}."
    end

    redirect_to admin_user_path(@user)
  end

  def sync_hackatime
    @user = User.find(params[:id])
    slack_identity = @user.identities.find_by(provider: "slack")

    if slack_identity
      HackatimeService.sync_user_projects(@user, slack_identity.uid)
      flash[:notice] = "Hackatime data synced for #{@user.display_name}."
    else
      flash[:alert] = "User does not have a Slack identity."
    end

    redirect_to admin_user_path(@user)
  end

  def impersonate
    unless current_user&.admin?
      flash[:alert] = "You are not authorized to impersonate users."
      redirect_to(request.referrer || root_path) and return
    end

    @user = User.find(params[:id])

    # Log the impersonation
    PaperTrail::Version.create!(
      item_type: "User",
      item_id: @user.id,
      event: "impersonate_start",
      whodunnit: current_user.id,
      object_changes: { impersonator_id: [ nil, current_user.id ] }.to_yaml
    )

    session[:impersonating_user_id] = @user.id
    session[:original_admin_id] = current_user.id

    flash[:notice] = "You are now impersonating #{@user.display_name}."
    redirect_to root_path
  end

  def stop_impersonating
    # This action needs to work while impersonating, so we check the session directly
    impersonated_user_id = session[:impersonating_user_id]
    original_admin_id = session[:original_admin_id]

    unless impersonated_user_id && original_admin_id
      flash[:alert] = "You are not currently impersonating anyone."
      redirect_to root_path and return
    end

    # Verify the original admin is actually an admin
    original_admin = User.find_by(id: original_admin_id)
    unless original_admin&.admin?
      flash[:alert] = "Invalid impersonation session."
      session.delete(:impersonating_user_id)
      session.delete(:original_admin_id)
      redirect_to root_path and return
    end

    # Log the end of impersonation
    PaperTrail::Version.create!(
      item_type: "User",
      item_id: impersonated_user_id,
      event: "impersonate_end",
      whodunnit: original_admin_id,
      object_changes: { impersonator_id: [ original_admin_id, nil ] }.to_yaml
    )

    session.delete(:impersonating_user_id)
    session.delete(:original_admin_id)

    flash[:notice] = "Stopped impersonating user."
    redirect_to admin_user_path(impersonated_user_id)
  end

    def user_not_authorized
      flash[:alert] = "You are not authorized to perform this action."
      redirect_to(request.referrer || root_path)
    end
end
