class Admin::ShopOrdersController < Admin::ApplicationController
  before_action :set_paper_trail_whodunnit
  def index
    # Determine view mode
    @view = params[:view] || "shop_orders"

    # Fulfillment team can only access fulfillment view - auto-redirect if needed
    if current_user.fulfillment_person? && !current_user.admin?
      if @view != "fulfillment"
        redirect_to admin_shop_orders_path(view: "fulfillment") and return
      end
      authorize :admin, :access_fulfillment_view?
    else
      authorize :admin, :access_shop_orders?
    end

    # Load fulfillment users for assignment dropdown (admins only, fulfillment view)
    if current_user.admin? && @view == "fulfillment"
      @fulfillment_users = User.where("'fulfillment_person' = ANY(granted_roles)").order(:display_name)
    end

    # Base query
    orders = ShopOrder.includes(:shop_item, :user, :accessory_orders, :assigned_to_user)

    # Apply status filter first if explicitly set (takes priority over view)
    if params[:status].present?
      orders = orders.where(aasm_state: params[:status])
    else
      # Apply view-specific scopes only if no explicit status filter
      case @view
      when "shop_orders"
        # Show pending, awaiting_verification, rejected, on_hold
        orders = orders.where(aasm_state: %w[pending awaiting_verification rejected on_hold])
      when "fulfillment"
        # Show awaiting_periodical_fulfillment and fulfilled
        orders = orders.where(aasm_state: %w[awaiting_periodical_fulfillment fulfilled])
      end

      # Set default status for fraud dept
      @default_status = "pending" if current_user.fraud_dept? && !current_user.admin?
      orders = orders.where(aasm_state: @default_status) if @default_status.present?
    end

    # Apply filters
    orders = orders.where(shop_item_id: params[:shop_item_id]) if params[:shop_item_id].present?
    orders = orders.where("created_at >= ?", params[:date_from]) if params[:date_from].present?
    orders = orders.where("created_at <= ?", params[:date_to]) if params[:date_to].present?

    if params[:user_search].present?
      search = "%#{ActiveRecord::Base.sanitize_sql_like(params[:user_search])}%"
      orders = orders.joins(:user).where("users.display_name ILIKE ? OR users.email ILIKE ? OR users.id::text = ? OR users.slack_id ILIKE ?", search, search, params[:user_search], search)
    end

    # Apply region filter using database-level query (now that orders have a region column)
    # Fulfillment persons see orders in their regions OR orders assigned to them OR orders with nil region (legacy/no address)
    if current_user.fulfillment_person? && !current_user.admin? && current_user.has_regions?
      orders = orders.where(region: current_user.regions)
                     .or(orders.where(region: nil))
                     .or(orders.where(assigned_to_user_id: current_user.id))
    elsif params[:region].present?
      orders = orders.where(region: params[:region].upcase)
    end

    # Calculate stats after region filter so counts respect user's assigned regions
    stats_orders = orders
    @c = {
      pending: stats_orders.where(aasm_state: "pending").count,
      awaiting_verification: stats_orders.where(aasm_state: "awaiting_verification").count,
      awaiting_fulfillment: stats_orders.where(aasm_state: "awaiting_periodical_fulfillment").count,
      fulfilled: stats_orders.where(aasm_state: "fulfilled").count,
      rejected: stats_orders.where(aasm_state: "rejected").count,
      on_hold: stats_orders.where(aasm_state: "on_hold").count
    }

    # Calculate average times
    fulfilled_orders = stats_orders.where(aasm_state: "fulfilled").where.not(fulfilled_at: nil)
    if fulfilled_orders.any?
      @f = fulfilled_orders.average("EXTRACT(EPOCH FROM (shop_orders.fulfilled_at - shop_orders.created_at))").to_f
    end

    # Sorting - always uses database ordering now
    orders = case params[:sort]
    when "id_asc" then orders.order(id: :asc)
    when "id_desc" then orders.order(id: :desc)
    when "created_at_asc" then orders.order(created_at: :asc)
    when "shells_asc" then orders.order(frozen_item_price: :asc)
    when "shells_desc" then orders.order(frozen_item_price: :desc)
    else orders.order(created_at: :desc)
    end

    # Grouping
    if params[:goob] == "true"
      @grouped_orders = orders.group_by(&:user).map do |user, user_orders|
        {
          user: user,
          orders: user_orders,
          total_items: user_orders.sum(&:quantity),
          total_shells: user_orders.sum { |o| o.total_cost || 0 },
          address: user_orders.first&.decrypted_address_for(current_user)
        }
      end
    else
      @shop_orders = orders
    end
  end

  def show
    if current_user.fulfillment_person? && !current_user.admin?
      authorize :admin, :access_fulfillment_view?
    else
      authorize :admin, :access_shop_orders?
    end
    @order = ShopOrder.find(params[:id])

    # Fulfillment persons can only view orders in their regions, assigned to them, or with nil region
    if current_user.fulfillment_person? && !current_user.admin?
      can_access = @order.assigned_to_user_id == current_user.id
      can_access ||= @order.region.nil?
      can_access ||= current_user.has_regions? && current_user.has_region?(@order.region)

      unless can_access
        redirect_to admin_shop_orders_path(view: "fulfillment"), alert: "You don't have access to this order" and return
      end
    end

    @can_view_address = @order.can_view_address?(current_user)

    # Load fulfillment users for assignment (admins only)
    if current_user.admin?
      @fulfillment_users = User.where("'fulfillment_person' = ANY(granted_roles)").order(:display_name)
    end

    # Load user's order history for fraud dept or order review
    @user_orders = @order.user.shop_orders.where.not(id: @order.id).order(created_at: :desc).limit(10)

    # User's shop orders summary stats
    user_orders = @order.user.shop_orders
    @user_order_stats = {
      total: user_orders.count,
      fulfilled: user_orders.where(aasm_state: "fulfilled").count,
      pending: user_orders.where(aasm_state: "pending").count,
      rejected: user_orders.where(aasm_state: "rejected").count,
      total_quantity: user_orders.sum(:quantity),
      on_hold: user_orders.where(aasm_state: "on_hold").count,
      awaiting_fulfillment: user_orders.where(aasm_state: "awaiting_periodical_fulfillment").count
    }
  end

  def reveal_address
    if current_user.fulfillment_person? && !current_user.admin?
      authorize :admin, :access_fulfillment_view?
    else
      authorize :admin, :access_shop_orders?
    end
    @order = ShopOrder.find(params[:id])

    if @order.can_view_address?(current_user)
      @decrypted_address = @order.decrypted_address_for(current_user)

      PaperTrail::Version.create!(
        item_type: "User",
        item_id: @order.user_id,
        event: "address_revealed",
        whodunnit: current_user.id.to_s,
        object_changes: { order_id: @order.id, shop_item: @order.shop_item&.name }
      )

      render turbo_stream: turbo_stream.replace(
        "address-content",
        partial: "address_details",
        locals: { address: @decrypted_address }
      )
    else
      render plain: "Unauthorized", status: :forbidden
    end
  end

  def approve
    authorize :admin, :access_shop_orders?
    @order = ShopOrder.find(params[:id])
    old_state = @order.aasm_state

    if @order.shop_item.respond_to?(:fulfill!)
      @order.approve!
      redirect_to admin_shop_orders_path, notice: "Order approved and fulfilled" and return
    end

    if @order.queue_for_fulfillment && @order.save
      PaperTrail::Version.create!(
        item_type: "ShopOrder",
        item_id: @order.id,
        event: "update",
        whodunnit: current_user.id,
        object_changes: {
          aasm_state: [ old_state, @order.aasm_state ]
        }
      )
      redirect_to admin_shop_orders_path, notice: "Order approved for fulfillment"
    else
      redirect_to admin_shop_order_path(@order), alert: "Failed to approve order: #{@order.errors.full_messages.join(', ')}"
    end
  end

  def reject
    authorize :admin, :access_shop_orders?
    @order = ShopOrder.find(params[:id])
    reason = params[:reason].presence || "No reason provided"
    old_state = @order.aasm_state

    if @order.mark_rejected(reason) && @order.save
      PaperTrail::Version.create!(
        item_type: "ShopOrder",
        item_id: @order.id,
        event: "update",
        whodunnit: current_user.id,
        object_changes: {
          aasm_state: [ old_state, @order.aasm_state ],
          rejection_reason: [ nil, reason ]
        }
      )
      redirect_to admin_shop_orders_path, notice: "Order rejected"
    else
      redirect_to admin_shop_order_path(@order), alert: "Failed to reject order: #{@order.errors.full_messages.join(', ')}"
    end
  end

  def place_on_hold
    authorize :admin, :access_shop_orders?
    @order = ShopOrder.find(params[:id])
    old_state = @order.aasm_state

    if @order.place_on_hold && @order.save
      PaperTrail::Version.create!(
        item_type: "ShopOrder",
        item_id: @order.id,
        event: "update",
        whodunnit: current_user.id,
        object_changes: {
          aasm_state: [ old_state, @order.aasm_state ]
        }
      )
      redirect_to admin_shop_orders_path, notice: "Order placed on hold"
    else
      redirect_to admin_shop_order_path(@order), alert: "Failed to place order on hold: #{@order.errors.full_messages.join(', ')}"
    end
  end

  def release_from_hold
    authorize :admin, :access_shop_orders?
    @order = ShopOrder.find(params[:id])
    old_state = @order.aasm_state

    if @order.take_off_hold && @order.save
      PaperTrail::Version.create!(
        item_type: "ShopOrder",
        item_id: @order.id,
        event: "update",
        whodunnit: current_user.id,
        object_changes: {
          aasm_state: [ old_state, @order.aasm_state ]
        }
      )
      redirect_to admin_shop_orders_path, notice: "Order released from hold"
    else
      redirect_to admin_shop_order_path(@order), alert: "Failed to release order from hold: #{@order.errors.full_messages.join(', ')}"
    end
  end

  def mark_fulfilled
    if current_user.fulfillment_person? && !current_user.admin?
      authorize :admin, :access_fulfillment_view?
    else
      authorize :admin, :access_shop_orders?
    end
    @order = ShopOrder.find(params[:id])
    old_state = @order.aasm_state

    if @order.mark_fulfilled && @order.save
      PaperTrail::Version.create!(
        item_type: "ShopOrder",
        item_id: @order.id,
        event: "update",
        whodunnit: current_user.id,
        object_changes: {
          aasm_state: [ old_state, @order.aasm_state ]
        }
      )
      redirect_to admin_shop_order_path(@order), notice: "Order marked as fulfilled"
    else
      redirect_to admin_shop_order_path(@order), alert: "Failed to mark order as fulfilled: #{@order.errors.full_messages.join(', ')}"
    end
  end

  def update_internal_notes
    if current_user.fulfillment_person? && !current_user.admin?
      authorize :admin, :access_fulfillment_view?
    else
      authorize :admin, :access_shop_orders?
    end
    @order = ShopOrder.find(params[:id])
    old_notes = @order.internal_notes

    if @order.update(internal_notes: params[:internal_notes])
      PaperTrail::Version.create!(
        item_type: "ShopOrder",
        item_id: @order.id,
        event: "update",
        whodunnit: current_user.id,
        object_changes: {
          internal_notes: [ old_notes, @order.internal_notes ]
        }
      )
      redirect_to admin_shop_order_path(@order), notice: "Internal notes updated"
    else
      redirect_to admin_shop_order_path(@order), alert: "Failed to update notes"
    end
  end

  def assign_user
    authorize :admin, :access_shop_orders?
    @order = ShopOrder.find(params[:id])
    old_assigned = @order.assigned_to_user_id

    new_assigned_id = params[:assigned_to_user_id].presence
    assigned_user = new_assigned_id ? User.find_by(id: new_assigned_id) : nil

    if @order.update(assigned_to_user_id: new_assigned_id)
      PaperTrail::Version.create!(
        item_type: "ShopOrder",
        item_id: @order.id,
        event: "assignment_updated",
        whodunnit: current_user.id,
        object_changes: {
          assigned_to_user_id: [ old_assigned, @order.assigned_to_user_id ]
        }
      )

      redirect_to admin_shop_orders_path(view: "fulfillment"), notice: "Order assigned to #{assigned_user&.display_name || 'nobody'}"
    else
      redirect_to admin_shop_orders_path(view: "fulfillment"), alert: "Failed to assign order"
    end
  end

  def cancel_hcb_grant
    authorize :admin, :manage_users?
    @order = ShopOrder.find(params[:id])

    unless @order.shop_card_grant.present?
      redirect_to admin_shop_order_path(@order), alert: "This order has no HCB grant to cancel"
      return
    end

    grant = @order.shop_card_grant
    begin
      HCBService.cancel_card_grant!(hashid: grant.hcb_grant_hashid)

      PaperTrail::Version.create!(
        item_type: "ShopOrder",
        item_id: @order.id,
        event: "hcb_grant_canceled",
        whodunnit: current_user.id,
        object_changes: { hcb_grant_hashid: grant.hcb_grant_hashid, canceled_by: current_user.display_name }.to_json
      )

      redirect_to admin_shop_order_path(@order), notice: "HCB grant canceled successfully"
    rescue => e
      redirect_to admin_shop_order_path(@order), alert: "Failed to cancel HCB grant: #{e.message}"
    end
  end
  def refresh_verification
    authorize :admin, :access_shop_orders?
    @order = ShopOrder.find(params[:id])

    unless @order.awaiting_verification?
      redirect_to admin_shop_order_path(@order), alert: "Order is not awaiting verification" and return
    end

    user = @order.user
    identity = user.identities.find_by(provider: "hack_club")

    unless identity&.access_token.present?
      redirect_to admin_shop_order_path(@order), alert: "User has no Hack Club identity token" and return
    end

    payload = HCAService.identity(identity.access_token)
    if payload.blank?
      redirect_to admin_shop_order_path(@order), alert: "Could not fetch verification status from HCA" and return
    end

    status = payload["verification_status"].to_s
    ysws_eligible = payload["ysws_eligible"] == true

    old_status = user.verification_status
    user.verification_status = status if User.verification_statuses.key?(status)
    user.ysws_eligible = ysws_eligible
    user.save!

    PaperTrail::Version.create!(
      item_type: "ShopOrder",
      item_id: @order.id,
      event: "verification_refreshed",
      whodunnit: current_user.id,
      object_changes: {
        user_verification_status: [ old_status, user.verification_status ],
        ysws_eligible: [ !ysws_eligible, ysws_eligible ]
      }
    )

    if user.eligible_for_shop?
      Shop::ProcessVerifiedOrdersJob.perform_later(user.id)
      redirect_to admin_shop_order_path(@order), notice: "User is now verified. Processing orders..."
    elsif user.should_reject_orders?
      user.reject_awaiting_verification_orders!
      redirect_to admin_shop_order_path(@order), notice: "User verification failed. Orders rejected."
    else
      redirect_to admin_shop_order_path(@order), notice: "Verification status updated to: #{user.verification_status}"
    end
  rescue StandardError => e
    Rails.logger.error "Failed to refresh verification status for order #{@order.id}: #{e.message}"
    redirect_to admin_shop_order_path(@order), alert: "Error refreshing verification: #{e.message}"
  end
end
