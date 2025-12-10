class ShopController < ApplicationController
  before_action :require_login

  def index
    @shop_open = true
    @user_region = user_region
    @region_options = Shop::Regionalizable::REGIONS.map do |code, config|
      { label: config[:name], value: code }
    end

    @featured_item = unless user_ordered_free_stickers?
      ShopItem.where(type: "ShopItem::FreeStickers")
              .includes(:image_attachment)
              .select { |item| item.enabled_in_region?(@user_region) }
              .first
    end
    @shop_items = ShopItem.buyable_standalone.includes(:image_attachment)
    @shop_items = @shop_items.where.not(type: "ShopItem::FreeStickers") if user_ordered_free_stickers?
    @user_balance = current_user.balance
  end

  def my_orders
    @orders = current_user.shop_orders
                          .where(parent_order_id: nil)
                          .includes(:accessory_orders, shop_item: { image_attachment: :blob })
                          .order(id: :desc)
  end

  def cancel_order
    result = current_user.cancel_shop_order(params[:order_id])

    if result[:success]
      redirect_to shop_my_orders_path, notice: "Order cancelled successfully!"
    else
      redirect_to shop_my_orders_path, alert: "Failed to cancel order: #{result[:error]}"
    end
  end

  def order
    @shop_item = ShopItem.find(params[:shop_item_id])

    unless @shop_item.buyable_by_self?
      redirect_to shop_path, alert: "This item cannot be ordered on its own."
      return
    end

    @accessories = @shop_item.available_accessories.includes(:image_attachment)
  end

  def update_region
    region = params[:region]&.upcase
    if Shop::Regionalizable::REGION_CODES.include?(region)
      current_user.update!(region: region)

      @user_region = region
      @shop_items = ShopItem.buyable_standalone.includes(:image_attachment)
      @shop_items = @shop_items.where.not(type: "ShopItem::FreeStickers") if user_ordered_free_stickers?
      @user_balance = current_user.balance
      @featured_item = unless user_ordered_free_stickers?
        ShopItem.where(type: "ShopItem::FreeStickers")
                .includes(:image_attachment)
                .select { |item| item.enabled_in_region?(@user_region) }
                .first
      end

      respond_to do |format|
        format.turbo_stream
        format.html { head :ok }
      end
    else
      head :unprocessable_entity
    end
  end

  def create_order
    if current_user.should_reject_orders?
      redirect_to shop_path, alert: "You're not eligible to place orders."
      return
    end

    @shop_item = ShopItem.find(params[:shop_item_id])

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

    # Calculate total cost
    item_total = @shop_item.ticket_cost * quantity
    accessories_total = @accessories.sum(:ticket_cost)
    total_cost = item_total + accessories_total

    # Check user balance
    if total_cost > current_user.balance
      redirect_to shop_order_path(shop_item_id: @shop_item.id), alert: "Insufficient balance. You need 🍪#{total_cost} but only have 🍪#{current_user.balance}."
      return
    end

    return redirect_to shop_order_path(shop_item_id: @shop_item.id), alert: "You need to have an address to make an order!" unless current_user.addresses.any?

    selected_address = current_user.addresses.find { |a| a["id"] == params[:address_id] } || current_user.addresses.first
    @order = current_user.shop_orders.new(
      shop_item: @shop_item,
      quantity: quantity,
      frozen_address: selected_address,
      accessory_ids: @accessories.pluck(:id)
    )

    @order.aasm_state = "pending" if @order.respond_to?(:aasm_state=)

    begin
      ActiveRecord::Base.transaction do
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

      if @shop_item.is_a?(ShopItem::FreeStickers)
        current_user.complete_tutorial_step!(:free_stickers)
      end

      unless current_user.eligible_for_shop?
        @order.queue_for_verification!
        @order.accessory_orders.each(&:queue_for_verification!)
        redirect_to shop_my_orders_path, notice: "Order placed! It will be processed once your identity is verified."
        return
      end

      if @shop_item.is_a?(ShopItem::FreeStickers)
        begin
          @shop_item.fulfill!(@order)
          @order.mark_stickers_received
          current_user.complete_tutorial_step! :free_stickers
        rescue => e
          Rails.logger.error "Free stickers fulfillment failed: #{e.message}"
          redirect_to shop_my_orders_path, alert: "Order placed but fulfillment failed. We'll process it shortly."
          return
        end
      end
      redirect_to shop_my_orders_path, notice: "Order placed successfully!"
    rescue ActiveRecord::RecordInvalid => e
      redirect_to shop_order_path(shop_item_id: @shop_item.id), alert: "Failed to place order: #{e.record.errors.full_messages.join(', ')}"
    end
  end

  private

  def user_region
    if current_user
      return current_user.region if current_user.region.present?

      primary_address = current_user.addresses.find { |a| a["primary"] } || current_user.addresses.first
      country = primary_address&.dig("country")
      region_from_address = Shop::Regionalizable.country_to_region(country)
      return region_from_address if region_from_address != "XX" || country.present?
    end

    Shop::Regionalizable.timezone_to_region(cookies[:timezone])
  end

  def user_ordered_free_stickers?
    @user_ordered_free_stickers ||= current_user.shop_orders
      .joins(:shop_item)
      .where(shop_items: { type: "ShopItem::FreeStickers" })
      .exists?
  end

  def require_login
    redirect_to root_path, alert: "Please log in first" and return unless current_user
  end
end
