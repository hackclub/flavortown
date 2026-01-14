class ShopController < ApplicationController
  before_action :require_login, except: [ :index ]

  def index
    @shop_open = Flipper.enabled?(:shop_open, current_user)
    @user_region = user_region
    @body_class = "shop-page"
    @region_options = Shop::Regionalizable::REGIONS.map do |code, config|
      { label: config[:name], value: code }
    end

    if current_user
      free_stickers_step = User::TutorialStep.find(:free_stickers)
      @show_shop_tutorial = free_stickers_step.deps_satisfied?(current_user.tutorial_steps) &&
                            !current_user.tutorial_step_completed?(:free_stickers)

      grant_free_stickers_welcome_cookies! if @show_shop_tutorial
    else
      @show_shop_tutorial = false
    end

    load_shop_items
  end

  def my_orders
    @orders = current_user.shop_orders
                          .where(parent_order_id: nil)
                          .includes(accessory_orders: { shop_item: { image_attachment: :blob } }, shop_item: { image_attachment: :blob })
                          .order(id: :desc)
    @show_tutorial_complete_dialog = session.delete(:show_tutorial_complete_dialog)
  end

  def cancel_order
    @order = current_user.shop_orders.find(params[:order_id])
    if @order.aasm_state == "fulfilled"
      redirect_to shop_my_orders_path, alert: "You cannot cancel an already fulfilled order."
      return
    end
    result = current_user.cancel_shop_order(params[:order_id])

    if result[:success]
      redirect_to shop_my_orders_path, notice: "Order cancelled successfully!"
    else
      redirect_to shop_my_orders_path, alert: "Failed to cancel order: #{result[:error]}"
    end
  end

  def order
    @shop_item = ShopItem.where(enabled: true).find(params[:shop_item_id])

    unless @shop_item.buyable_by_self?
      redirect_to shop_path, alert: "This item cannot be ordered on its own."
      return
    end

    @user_region = user_region
    @sale_price = @shop_item.price_for_region(@user_region)
    @accessories = @shop_item.available_accessories.includes(:image_attachment)
    ahoy.track "Viewed shop item", shop_item_id: @shop_item.id
  end

  def update_region
    region = params[:region]&.upcase
    unless Shop::Regionalizable::REGION_CODES.include?(region)
      return head :unprocessable_entity
    end

    current_user.update!(shop_region: region)
    @user_region = region
    load_shop_items

    respond_to do |format|
      format.turbo_stream
      format.html { head :ok }
    end
  end

  def create_order
    if current_user.should_reject_orders?
      redirect_to shop_path, alert: "You're not eligible to place orders."
      return
    end

    @shop_item = ShopItem.where(enabled: true).find(params[:shop_item_id])

    unless @shop_item.buyable_by_self?
      redirect_to shop_path, alert: "This item cannot be ordered on its own."
      return
    end

    quantity = params[:quantity].to_i
    accessory_ids = Array(params[:accessory_ids]).map(&:to_i).reject(&:zero?)

    # Collect accessory IDs from tagged radio buttons (accessory_tag_* params)
    params.each do |key, value|
      if key.to_s.start_with?("accessory_tag_") && value.present?
        accessory_ids << value.to_i
      end
    end
    accessory_ids = accessory_ids.uniq.reject(&:zero?)

    if quantity <= 0
      redirect_to shop_order_path(shop_item_id: @shop_item.id), alert: "Quantity must be greater than 0"
      return
    end

    # Validate accessories belong to this item
    @accessories = if accessory_ids.any?
                     @shop_item.available_accessories.where(id: accessory_ids)
    else
                     []
    end

    # Calculate total cost (applying sale discount via price_for_region)
    region = user_region
    item_price = @shop_item.price_for_region(region)
    item_total = item_price * quantity
    accessories_total = @accessories.sum { |a| a.price_for_region(region) }
    total_cost = item_total + accessories_total

    return redirect_to shop_order_path(shop_item_id: @shop_item.id), alert: "You need to have an address to make an order!" unless current_user.addresses.any?

    selected_address = current_user.addresses.find { |a| a["id"] == params[:address_id] } || current_user.addresses.first

    begin
      ActiveRecord::Base.transaction do
        current_user.lock!
        user_balance = current_user.balance

        if total_cost > user_balance
          redirect_to shop_order_path(shop_item_id: @shop_item.id), alert: "Insufficient balance. You need 🍪#{total_cost} but only have 🍪#{user_balance}."
          return
        end

        @order = current_user.shop_orders.new(
          shop_item: @shop_item,
          quantity: quantity,
          frozen_address: selected_address,
          accessory_ids: @accessories.pluck(:id)
        )
        @order.aasm_state = "pending" if @order.respond_to?(:aasm_state=)
        @order.save!

        # Create orders for each accessory
        @accessories.each do |accessory|
          accessory_order = current_user.shop_orders.new(
            shop_item: accessory,
            quantity: 1,
            frozen_address: selected_address,
            parent_order_id: @order.id
          )
          accessory_order.aasm_state = "pending" if accessory_order.respond_to?(:aasm_state=)
          accessory_order.save!
        end
      end

      handle_free_stickers_order! if @shop_item.is_a?(ShopItem::FreeStickers)

      unless current_user.eligible_for_shop?
        @order.queue_for_verification!
        @order.accessory_orders.each(&:queue_for_verification!)
        redirect_to shop_my_orders_path, notice: "Order placed! It will be processed once your identity is verified."
        return
      end

      return if @shop_item.is_a?(ShopItem::FreeStickers) && !fulfill_free_stickers!
      redirect_to shop_my_orders_path, notice: "Order placed successfully!"
    rescue ActiveRecord::RecordInvalid => e
      redirect_to shop_order_path(shop_item_id: @shop_item.id), alert: "Failed to place order: #{e.record.errors.full_messages.join(', ')}"
    end
  end

  private

  def load_shop_items
    excluded_free_stickers = current_user && has_ordered_free_stickers?
    @shop_items = ShopItem.cached_buyable_standalone
    @shop_items = @shop_items.reject { |item| item.type == "ShopItem::FreeStickers" } if excluded_free_stickers
    @featured_item = featured_free_stickers_item unless excluded_free_stickers
    @user_balance = current_user&.balance || 0
  end

  def has_ordered_free_stickers?
    current_user.has_gotten_free_stickers? ||
      current_user.shop_orders.joins(:shop_item).where(shop_items: { type: "ShopItem::FreeStickers" }).exists?
  end

  def featured_free_stickers_item
    item = ShopItem.find_by(id: 1, type: "ShopItem::FreeStickers", enabled: true)
    item if item&.enabled_in_region?(@user_region)
  end

  def grant_free_stickers_welcome_cookies!
    unless current_user.ledger_entries.exists?(reason: "Free Stickers Welcome Grant")
      current_user.ledger_entries.create!(
        amount: 10, reason: "Free Stickers Welcome Grant", created_by: "System", ledgerable: current_user
      )
    end
    order_url = url_for(controller: "shop", action: "order", shop_item_id: 1, only_path: false)
    session[:tutorial_redirect_url] = HCAService.address_portal_url(return_to: order_url)
  end

  def handle_free_stickers_order!
    current_user.complete_tutorial_step!(:free_stickers)
    session.delete(:tutorial_redirect_url)
    session[:show_tutorial_complete_dialog] = true
  end

  def fulfill_free_stickers!
    @shop_item.fulfill!(@order)
    @order.mark_stickers_received
    true
  rescue => e
    Rails.logger.error "Free stickers fulfillment failed: #{e.message}"
    Sentry.capture_exception(e, extra: { order_id: @order.id, user_id: current_user.id })
    redirect_to shop_my_orders_path, alert: "Order placed but fulfillment failed. We'll process it shortly."
    false
  end

  def user_region
    if current_user
      # Use explicitly set shop region if available
      return current_user.shop_region if current_user.shop_region.present?

      # For fulfillment persons with regions, return the first one for shop filtering
      return current_user.regions.first if current_user.has_regions?

      primary_address = current_user.addresses.find { |a| a["primary"] } || current_user.addresses.first
      country = primary_address&.dig("country")
      region_from_address = Shop::Regionalizable.country_to_region(country)
      return region_from_address if region_from_address != "XX" || country.present?
    end

    Shop::Regionalizable.timezone_to_region(cookies[:timezone])
  end

  def require_login
    redirect_to root_path, alert: "Please log in first" and return unless current_user
  end
end
