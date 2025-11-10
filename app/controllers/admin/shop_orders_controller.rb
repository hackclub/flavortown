class Admin::ShopOrdersController < Admin::ApplicationController
  def index
    authorize :admin, :shop_orders?
    
    # Determine view mode
    @view = params[:view] || 'shop_orders'
    
    # Check authorization for fulfillment view
    if @view == 'fulfillment'
      unless current_user.admin? || current_user.fulfillment_person?
        flash[:alert] = "You don't have permission to access fulfillment view"
        redirect_to admin_shop_orders_path(view: 'shop_orders') and return
      end
    end
    
    # Base query
    orders = ShopOrder.includes(:shop_item, :user)
    
    # Apply view-specific scopes
    case @view
    when 'shop_orders'
      # Show pending, rejected, on_hold
      orders = orders.where(aasm_state: %w[pending rejected on_hold])
    when 'fulfillment'
      # Show awaiting_periodical_fulfillment and fulfilled
      orders = orders.where(aasm_state: %w[awaiting_periodical_fulfillment fulfilled])
    end
    
    # Apply filters
    orders = orders.where(shop_item_id: params[:shop_item_id]) if params[:shop_item_id].present?
    orders = orders.where(aasm_state: params[:status]) if params[:status].present?
    orders = orders.where("created_at >= ?", params[:date_from]) if params[:date_from].present?
    orders = orders.where("created_at <= ?", params[:date_to]) if params[:date_to].present?
    
    if params[:user_search].present?
      search = "%#{params[:user_search]}%"
      orders = orders.joins(:user).where("users.display_name ILIKE ? OR users.email ILIKE ?", search, search)
    end
    
    # Calculate stats
    stats_orders = orders
    @c = {
      pending: stats_orders.where(aasm_state: 'pending').count,
      awaiting_fulfillment: stats_orders.where(aasm_state: 'awaiting_periodical_fulfillment').count,
      fulfilled: stats_orders.where(aasm_state: 'fulfilled').count,
      rejected: stats_orders.where(aasm_state: 'rejected').count,
      on_hold: stats_orders.where(aasm_state: 'on_hold').count
    }
    
    # Calculate average times
    fulfilled_orders = stats_orders.where(aasm_state: 'fulfilled').where.not(fulfilled_at: nil)
    if fulfilled_orders.any?
      @f = fulfilled_orders.average("EXTRACT(EPOCH FROM (shop_orders.fulfilled_at - shop_orders.created_at))").to_f
    end
    
    # Sorting
    case params[:sort]
    when 'id_asc'
      orders = orders.order(id: :asc)
    when 'id_desc'
      orders = orders.order(id: :desc)
    when 'created_at_asc'
      orders = orders.order(created_at: :asc)
    when 'shells_asc'
      orders = orders.order(frozen_item_price: :asc)
    when 'shells_desc'
      orders = orders.order(frozen_item_price: :desc)
    else
      orders = orders.order(created_at: :desc)
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
    authorize :admin, :shop_orders?
    @order = ShopOrder.find(params[:id])
    @can_view_address = @order.can_view_address?(current_user)
  end

  def reveal_address
    authorize :admin, :shop_orders?
    @order = ShopOrder.find(params[:id])
    
    if @order.can_view_address?(current_user)
      @decrypted_address = @order.decrypted_address_for(current_user)
      render turbo_stream: turbo_stream.replace(
        "address-content",
        partial: "address_details",
        locals: { address: @decrypted_address }
      )
    else
      render plain: "Unauthorized", status: :forbidden
    end
  end
end
