class ShopController < ApplicationController
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
    @shop_items = ShopItem.all.includes(:image_attachment)
    @shop_items = @shop_items.where.not(type: "ShopItem::FreeStickers") if user_ordered_free_stickers?
    @user_balance = current_user.balance
  end

  def my_orders
    @orders = current_user.shop_orders.includes(shop_item: { image_attachment: :blob }).order(id: :desc)
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
  end

  def update_region
    region = params[:region]&.upcase
    if Shop::Regionalizable::REGION_CODES.include?(region)
      current_user.update!(region: region)

      @user_region = region
      @shop_items = ShopItem.all.includes(:image_attachment)
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
    @shop_item = ShopItem.find(params[:shop_item_id])
    quantity = params[:quantity].to_i

    if quantity <= 0
        redirect_to shop_order_path(shop_item_id: @shop_item.id), alert: "Quantity must be greater than 0"
        return
    end

    # Create the order
    # This is a simplified version. In a real app, you'd want to:
    # 1. Check stock
    # 2. Check balance/charge user
    # 3. Handle different item types

    selected_address = current_user.addresses.find { |a| a["id"] == params[:address_id] } || current_user.addresses.first
    @order = current_user.shop_orders.new(
      shop_item: @shop_item,
      quantity: quantity,
      frozen_address: selected_address
    )

    @order.aasm_state = "pending" if @order.respond_to?(:aasm_state=)

    if @order.save
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
    else
      redirect_to shop_order_path(shop_item_id: @shop_item.id), alert: "Failed to place order: #{@order.errors.full_messages.join(', ')}"
    end
  end

  private

  def user_region
    return current_user.region if current_user.region.present?

    primary_address = current_user.addresses.find { |a| a["primary"] } || current_user.addresses.first
    country = primary_address&.dig("country")
    Shop::Regionalizable.country_to_region(country)
  end

  def user_ordered_free_stickers?
    @user_ordered_free_stickers ||= current_user.shop_orders
      .joins(:shop_item)
      .where(shop_items: { type: "ShopItem::FreeStickers" })
      .exists?
  end
end
