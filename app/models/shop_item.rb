# == Schema Information
#
# Table name: shop_items
#
#  id                                :bigint           not null, primary key
#  agh_contents                      :jsonb
#  description                       :string
#  enabled                           :boolean
#  enabled_au                        :boolean
#  enabled_ca                        :boolean
#  enabled_eu                        :boolean
#  enabled_in                        :boolean
#  enabled_us                        :boolean
#  enabled_xx                        :boolean
#  hacker_score                      :integer
#  hcb_category_lock                 :string
#  hcb_keyword_lock                  :string
#  hcb_merchant_lock                 :string
#  hcb_preauthorization_instructions :text
#  internal_description              :string
#  limited                           :boolean
#  max_qty                           :integer
#  name                              :string
#  one_per_person_ever               :boolean
#  price_offset_au                   :decimal(, )
#  price_offset_ca                   :decimal(, )
#  price_offset_eu                   :decimal(, )
#  price_offset_in                   :decimal(, )
#  price_offset_us                   :decimal(, )
#  price_offset_xx                   :decimal(, )
#  sale_percentage                   :integer
#  show_in_carousel                  :boolean
#  site_action                       :integer
#  special                           :boolean
#  stock                             :integer
#  ticket_cost                       :decimal(, )
#  type                              :string
#  unlock_on                         :date
#  usd_cost                          :decimal(, )
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#
class ShopItem < ApplicationRecord
  has_paper_trail

  include Shop::Regionalizable

  MANUAL_FULFILLMENT_TYPES = [
    "ShopItem::HCBGrant",
    "ShopItem::HCBPreauthGrant",
    "ShopItem::ThirdPartyPhysical",
    "ShopItem::SpecialFulfillmentItem"
  ].freeze

  scope :shown_in_carousel, -> { where(show_in_carousel: true) }
  scope :manually_fulfilled, -> { where(type: MANUAL_FULFILLMENT_TYPES) }
  scope :enabled, -> { where(enabled: true) }

  has_one_attached :image do |attachable|
    attachable.variant :carousel_sm,
                       resize_to_limit: [ 160, nil ],
                       format: :webp,
                       preprocessed: true,
                       saver: { strip: true, quality: 75 }

    attachable.variant :carousel_md,
                       resize_to_limit: [ 240, nil ],
                       format: :webp,
                       preprocessed: true,
                       saver: { strip: true, quality: 75 }

    attachable.variant :carousel_lg,
                       resize_to_limit: [ 360, nil ],
                       format: :webp,
                       preprocessed: true,
                       saver: { strip: true, quality: 75 }
  end
  has_many :shop_orders, dependent: :restrict_with_error

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
