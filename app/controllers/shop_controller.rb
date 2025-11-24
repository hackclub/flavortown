class ShopController < ApplicationController
  def index
    @shop_open = true
    @featured_item = ShopItem.where(type: "ShopItem::FreeStickers").includes(:image_attachment).first
    @shop_items = ShopItem.all.includes(:image_attachment)
  end

  def my_orders
    @orders = current_user.shop_orders.includes(shop_item: { image_attachment: :blob })
  end

  def order
    @shop_item = ShopItem.find(params[:shop_item_id])
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
      # Assuming address is stored as json in user model now, but for order history we might want to snapshot it
      # For now just getting it to save
    )

    # Set initial state if using AASM
    if @shop_item.is_a?(ShopItem::FreeStickers)
        @order.aasm_state = "fulfilled"
        @order.fulfilled_at = Time.current
        @order.mark_stickers_received
    elsif @order.respond_to?(:aasm_state=)
        @order.aasm_state = "pending"
    end

    if @order.save
        redirect_to shop_my_orders_path, notice: "Order placed successfully!"
    else
        redirect_to shop_order_path(shop_item_id: @shop_item.id), alert: "Failed to place order: #{@order.errors.full_messages.join(', ')}"
    end
  end
end
