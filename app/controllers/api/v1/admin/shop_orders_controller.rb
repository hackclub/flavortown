class Api::V1::Admin::ShopOrdersController < Api::V1::Admin::BaseController
  before_action :set_item, except: %i[order fulfill]

  def stats
    orders = @item.shop_orders.where.not(aasm_state: "rejected")
    render json: {
      shop_item_id: @item.id,
      total_orders: orders.count,
      unique_buyers: orders.distinct.count(:user_id)
    }
  end

  def order
    o = ShopOrder.find(params[:order_id])
    render json: o.as_json(except: %i[frozen_address_ciphertext])
  end

  def fulfill
    o = ShopOrder.find(params[:order_id])

    unless o.may_mark_fulfilled?
      render json: { error: "order is in #{o.aasm_state} and can not be marked as fulfilled" }, status: :unprocessable_entity and return
    end

    if o.mark_fulfilled(params[:external_ref].presence, params[:fulfillment_cost].presence, current_api_user.display_name) && o.save
      render json: o.as_json(except: %i[frozen_address_ciphertext])
    else
      render json: { errors: o.errors.full_messages }, status: :unprocessable_entity
    end
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
