class Api::V1::Admin::ShopOrdersController < Api::V1::Admin::BaseController
  before_action :set_item

  def stats
    orders = @item.shop_orders.where.not(aasm_state: "rejected")
    render json: {
      shop_item_id: @item.id,
      total_orders: orders.count,
      unique_buyers: orders.distinct.count(:user_id)
    }
  end

  def leaderboard
    buyers = @item.shop_orders
      .where.not(aasm_state: "rejected")
      .group(:user_id)
      .order("count_all desc")
      .count

    users = User.where(id: buyers.keys).index_by(&:id)

    render json: buyers.map { |uid, count|
      u = users[uid]
      { user_id: u.id, display_name: u.display_name, avatar: u.avatar, order_count: count }
    }
  end

  private

  def set_item
    @item = ShopItem.find(params[:shop_item_id])
  end
end
