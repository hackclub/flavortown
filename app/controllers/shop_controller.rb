class ShopController < ApplicationController
  def index
    @shop_open = true
    @user_region = user_region
    @region_options = Shop::Regionalizable::REGIONS.map do |code, config|
      { label: config[:name], value: code }
    end

    @featured_item = ShopItem.where(type: "ShopItem::FreeStickers")
                             .includes(:image_attachment)
                             .select { |item| item.enabled_in_region?(@user_region) }
                             .first
    @shop_items = ShopItem.all.includes(:image_attachment)
    @user_balance = current_user.balance
  end

  def my_orders
    @orders = current_user.shop_orders.includes(shop_item: { image_attachment: :blob })
  end

  def order
    @shop_item = ShopItem.find(params[:shop_item_id])
  end

  def update_region
    region = params[:region]&.upcase
    if Shop::Regionalizable::REGION_CODES.include?(region)
      current_user.update!(region: region)
      head :ok
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

    @order = current_user.shop_orders.new(
      shop_item: @shop_item,
      quantity: quantity,
      frozen_address: current_user.address
    )

    # Set initial state if using AASM
    if @shop_item.is_a?(ShopItem::FreeStickers)
        @order.aasm_state = "fulfilled"
        @order.fulfilled_at = Time.current
    elsif @order.respond_to?(:aasm_state=)
        @order.aasm_state = "pending"
    end

    if @order.save
        @order.mark_stickers_received if @shop_item.is_a?(ShopItem::FreeStickers)
        redirect_to shop_my_orders_path, notice: "Order placed successfully!"
    else
        redirect_to shop_order_path(shop_item_id: @shop_item.id), alert: "Failed to place order: #{@order.errors.full_messages.join(', ')}"
    end
  end

  private

  def user_region
    return current_user.region if current_user.region.present?

    country = current_user.address&.dig("country") || current_user.address&.dig(:country)
    Shop::Regionalizable.country_to_region(country)
  end
end
