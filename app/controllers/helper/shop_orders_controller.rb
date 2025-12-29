module Helper
  class ShopOrdersController < ApplicationController
    def index
      authorize :helper, :view_shop_orders?

      o = ShopOrder.includes(:shop_item, :user)

      o = o.where(shop_item_id: params[:shop_item_id]) if params[:shop_item_id].present?
      o = o.where(aasm_state: params[:status]) if params[:status].present?
      o = o.where("created_at >= ?", params[:date_from]) if params[:date_from].present?
      o = o.where("created_at <= ?", params[:date_to]) if params[:date_to].present?

      if params[:user_search].present?
        s = "%#{ActiveRecord::Base.sanitize_sql_like(params[:user_search])}%"
        o = o.joins(:user).where("users.display_name ILIKE ? OR users.email ILIKE ? OR users.slack ILIKE ?", s, s, s)
      end

      @pagy, @orders = pagy(:offset, o.order(created_at: :desc))
    end

    def show
      authorize :helper, :view_shop_orders?
      @order = ShopOrder.includes(:shop_item, :user).find(params[:id])
    end
  end
end
