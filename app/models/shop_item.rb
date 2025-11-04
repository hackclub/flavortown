class ShopItem < ApplicationRecord
 include Shop::Regionalizable
  #   scope :black_market, -> { where(requires_black_market: true) }
  #   scope :not_black_market, -> { where(requires_black_market: [ false, nil ]) }
  scope :shown_in_carousel, -> { where(show_in_carousel: true) }
  #   scope :manually_fulfilled, -> { where(type: MANUAL_FULFILLMENT_TYPES) }
  scope :enabled, -> { where(enabled: true) }

  has_one_attached :image
  has_many :shop_orders

  def is_free?
    self.ticket_cost.zero?
  end
  def on_sale?
    sale_percentage.present? && sale_percentage > 0
  end

  def average_hours_estimated
    return 0 unless ticket_cost.present?
    ticket_cost / (Rails.configuration.game_constants.tickets_per_dollar * Rails.configuration.game_constants.dollars_per_mean_hour)
  end

  def hours_estimated
    average_hours_estimated.to_i
  end

  def fixed_estimate(price)
    return 0 unless price.present? && price > 0
    price / (Rails.configuration.game_constants.tickets_per_dollar * Rails.configuration.game_constants.dollars_per_mean_hour)
  end

  def remaining_stock
    return nil unless limited? && stock.present?
    # ordered_quantity = shop_orders.worth_counting.sum(:quantity)
    # stock - ordered_quantity
    nil
  end

  def out_of_stock?
    limited? && remaining_stock && remaining_stock <= 0
  end
end
