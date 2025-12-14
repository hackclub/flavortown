class Admin::UsersController < Admin::ApplicationController
    def index
      @query = params[:query]

      users = User.all.with_roles
      if @query.present?
        q = "%#{@query}%"
        users = users.where("email ILIKE ? OR display_name ILIKE ?", q, q)
      end

      @pagy, @users = pagy(:offset, users.order(:id))
    end

    def show
      @user = User.with_roles.includes(:identities).find(params[:id])

      # Get all actions performed on this user (filter out empty updates)
      user_versions = PaperTrail::Version
        .where(item_type: "User", item_id: @user.id)
        .order(created_at: :desc)
        .select do |v|
          next true unless v.event == "update"
          # With native JSONB, object_changes is already a hash
          changes = v.object_changes || {}
          changes.keys.any? { |k| !%w[updated_at synced_at].include?(k.to_s) }
        end

      # Get ledger entries for this user
      ledger_entries = @user.ledger_entries.includes(:ledgerable).order(created_at: :desc)

      # Combine and sort by created_at (role changes are now in user_versions as role_promoted/role_demoted events)
      @user_actions = (user_versions + ledger_entries).sort_by(&:created_at).reverse
    end

    def user_perms
      authorize :admin, :manage_users?
      @users = User.joins(:role_assignments).distinct.order(:id)
    end

    def promote_role
      authorize :admin, :manage_user_roles?

      @user = User.find(params[:id])
      role_name = params[:role_name]

      if role_name == "admin" && !current_user.super_admin?
        flash[:alert] = "Only super admins can promote to admin."
        return redirect_to admin_user_path(@user)
      end

      @user.role_assignments.create!(role: role_name)

      # Create explicit audit entry on User
      PaperTrail::Version.create!(
        item_type: "User",
        item_id: @user.id,
        event: "role_promoted",
        whodunnit: current_user.id.to_s,
        object_changes: { role: role_name }.to_yaml
      )

      flash[:notice] = "User promoted to #{role_name.titleize}."

      redirect_to admin_user_path(@user)
    end

  def demote_role
    authorize :admin, :manage_user_roles?

    @user = User.find(params[:id])
    role_name = params[:role_name]

    if role_name == "super_admin" && !current_user.super_admin?
      flash[:alert] = "Only super admins can demote super admin."
      return redirect_to admin_user_path(@user)
    end

    role_assignment = @user.role_assignments.find_by(role: User::RoleAssignment.roles[role_name])

    if role_assignment
      role_assignment.destroy!

      # Create explicit audit entry on User
      PaperTrail::Version.create!(
        item_type: "User",
        item_id: @user.id,
        event: "role_demoted",
        whodunnit: current_user.id.to_s,
        object_changes: { role: role_name }.to_yaml
      )

      flash[:notice] = "User demoted from #{role_name.titleize}."
    else
      flash[:alert] = "Unable to demote user from #{role_name.titleize}."
    end

    redirect_to admin_user_path(@user)
  end

  def toggle_flipper
    authorize :admin, :access_flipper?

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
    authorize :admin, :manage_users?
    @user = User.find(params[:id])
    hackatime_identity = @user.identities.find_by(provider: "hack_club")

    if hackatime_identity
      HackatimeService.sync_user_projects(@user, hackatime_identity.uid)
      flash[:notice] = "Hackatime data synced for #{@user.display_name}."
    else
      flash[:alert] = "User does not have a Slack identity."
    end

    redirect_to admin_user_path(@user)
  end

  def mass_reject_orders
    authorize :admin, :access_shop_orders?
    @user = User.find(params[:id])
    reason = params[:reason].presence || "Rejected by fraud department"

    orders = @user.shop_orders.where(aasm_state: %w[pending awaiting_periodical_fulfillment])
    count = 0

    orders.each do |order|
      old_state = order.aasm_state
      if order.mark_rejected(reason) && order.save
        PaperTrail::Version.create!(
          item_type: "ShopOrder",
          item_id: order.id,
          event: "update",
          whodunnit: current_user.id,
          object_changes: {
            aasm_state: [ old_state, order.aasm_state ],
            rejection_reason: [ nil, reason ]
          }.to_yaml
        )
        count += 1
      end
    end

    flash[:notice] = "Rejected #{count} order(s) for #{@user.display_name}."
    redirect_to admin_user_path(@user)
  end

  def adjust_balance
    authorize :admin, :manage_users?
    @user = User.find(params[:id])

    amount = params[:amount].to_i
    reason = params[:reason].presence

    if amount.zero?
      flash[:alert] = "Amount cannot be zero."
      return redirect_to admin_user_path(@user)
    end

    if reason.blank?
      flash[:alert] = "Reason is required."
      return redirect_to admin_user_path(@user)
    end

    @user.ledger_entries.create!(
      amount: amount,
      reason: reason,
      created_by: "#{current_user.display_name} (#{current_user.id})",
      ledgerable: @user
    )

    flash[:notice] = "Balance adjusted by #{amount} for #{@user.display_name}."
    redirect_to admin_user_path(@user)
  end

  def ban
    authorize :admin, :ban_users?
    @user = User.find(params[:id])
    reason = params[:reason].presence

    PaperTrail.request(whodunnit: current_user.id) do
      @user.ban!(reason: reason)
    end

    flash[:notice] = "#{@user.display_name} has been banned."
    redirect_to admin_user_path(@user)
  end

  def unban
    authorize :admin, :ban_users?
    @user = User.find(params[:id])

    PaperTrail.request(whodunnit: current_user.id) do
      @user.unban!
    end

    flash[:notice] = "#{@user.display_name} has been unbanned."
    redirect_to admin_user_path(@user)
  end
end
