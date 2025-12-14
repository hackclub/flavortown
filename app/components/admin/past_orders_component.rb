module Admin
  class PastOrdersComponent < ViewComponent::Base
    attr_reader :user, :orders, :title, :collapsible

    def initialize(user:, orders: nil, title: "Past Orders", collapsible: true)
      @user = user
      @orders = orders || user.shop_orders.includes(:shop_item).order(created_at: :desc)
      @title = title
      @collapsible = collapsible
    end

    def render?
      orders.any?
    end
  end
end
