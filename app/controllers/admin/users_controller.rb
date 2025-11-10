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
    PaperTrail.request(whodunnit: current_user.id) do
    PaperTrail::Version.create!(
      item_type: 'User::RoleAssignment',
      item_id: role_assignment.id,
      event: 'create',
      object_changes: { user_id: [nil, 123], role_id: [nil, 2] }.to_yaml
    )
end
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

  def toggle_flipper
    @user = User.find(params[:id])
    feature = params[:feature].to_sym

    if Flipper.enabled?(feature, @user)
      Flipper.disable(feature, @user)
      PaperTrail::Version.create!(
        item_type: 'User',
        item_id: @user.id,
        event: 'flipper_disable',
        whodunnit: current_user.id,
        object_changes: { feature: [feature.to_s, nil], status: ['enabled', 'disabled'] }.to_yaml
      )
      flash[:notice] = "Disabled #{feature} for #{@user.display_name}."
    else
      Flipper.enable(feature, @user)
      PaperTrail::Version.create!(
        item_type: 'User',
        item_id: @user.id,
        event: 'flipper_enable',
        whodunnit: current_user.id,
        object_changes: { feature: [nil, feature.to_s], status: ['disabled', 'enabled'] }.to_yaml
      )
      flash[:notice] = "Enabled #{feature} for #{@user.display_name}."
    end

    redirect_to admin_user_path(@user)
  end

    def user_not_authorized
      flash[:alert] = "You are not authorized to perform this action."
      redirect_to(request.referrer || root_path)
    end
end
