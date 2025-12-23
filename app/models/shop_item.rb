# == Schema Information
#
# Table name: shop_items
#
#  id                                :bigint           not null, primary key
#  accessory_tag                     :string
#  agh_contents                      :jsonb
#  attached_shop_item_ids            :bigint           default([]), is an Array
#  buyable_by_self                   :boolean          default(TRUE)
#  default_assigned_user_id_au       :bigint
#  default_assigned_user_id_ca       :bigint
#  default_assigned_user_id_eu       :bigint
#  default_assigned_user_id_in       :bigint
#  default_assigned_user_id_uk       :bigint
#  default_assigned_user_id_us       :bigint
#  default_assigned_user_id_xx       :bigint
#  description                       :string
#  enabled                           :boolean
#  enabled_au                        :boolean
#  enabled_ca                        :boolean
#  enabled_eu                        :boolean
#  enabled_in                        :boolean
#  enabled_uk                        :boolean
#  enabled_us                        :boolean
#  enabled_xx                        :boolean
#  hacker_score                      :integer
#  hcb_category_lock                 :string
#  hcb_keyword_lock                  :string
#  hcb_merchant_lock                 :string
#  hcb_preauthorization_instructions :text
#  internal_description              :string
#  limited                           :boolean
#  long_description                  :text
#  max_qty                           :integer
#  name                              :string
#  old_prices                        :integer          default([]), is an Array
#  one_per_person_ever               :boolean
#  payout_percentage                 :integer          default(0)
#  price_offset_au                   :decimal(, )
#  price_offset_ca                   :decimal(, )
#  price_offset_eu                   :decimal(, )
#  price_offset_in                   :decimal(, )
#  price_offset_uk                   :decimal(10, 2)
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
#  default_assigned_user_id          :bigint
#  user_id                           :bigint
#
# Indexes
#
#  index_shop_items_on_default_assigned_user_id  (default_assigned_user_id)
#  index_shop_items_on_user_id                   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (default_assigned_user_id => users.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id)
#
class ShopItem < ApplicationRecord
  has_paper_trail

  include Shop::Regionalizable

  after_commit :refresh_carousel_cache, if: :carousel_relevant_change?
  after_commit :invalidate_buyable_standalone_cache

  BUYABLE_STANDALONE_CACHE_KEY = "shop_items/buyable_standalone"

  def self.cached_buyable_standalone
    Rails.cache.fetch(BUYABLE_STANDALONE_CACHE_KEY, expires_in: 5.minutes) do
      enabled.buyable_standalone.includes(image_attachment: :blob).to_a
    end
  end

  def self.invalidate_buyable_standalone_cache!
    Rails.cache.delete(BUYABLE_STANDALONE_CACHE_KEY)
  end

  MANUAL_FULFILLMENT_TYPES = [
    "ShopItem::HCBGrant",
    "ShopItem::HCBPreauthGrant",
    "ShopItem::ThirdPartyPhysical",
    "ShopItem::SpecialFulfillmentItem"
  ].freeze

  scope :shown_in_carousel, -> { where(show_in_carousel: true) }
  scope :manually_fulfilled, -> { where(type: MANUAL_FULFILLMENT_TYPES) }
  scope :enabled, -> { where(enabled: true) }
  scope :buyable_standalone, -> { where.not(type: "ShopItem::Accessory").or(where(buyable_by_self: true)) }

  belongs_to :seller, class_name: "User", foreign_key: :user_id, optional: true
  belongs_to :default_assigned_user, class_name: "User", optional: true
  belongs_to :default_assigned_user_us, class_name: "User", optional: true
  belongs_to :default_assigned_user_eu, class_name: "User", optional: true
  belongs_to :default_assigned_user_uk, class_name: "User", optional: true
  belongs_to :default_assigned_user_ca, class_name: "User", optional: true
  belongs_to :default_assigned_user_au, class_name: "User", optional: true
  belongs_to :default_assigned_user_in, class_name: "User", optional: true
  belongs_to :default_assigned_user_xx, class_name: "User", optional: true

  def default_assignee_for_region(region)
    return default_assigned_user_id unless region.present?

    regional_assignee = send("default_assigned_user_id_#{region.downcase}") rescue nil
    regional_assignee.presence || default_assigned_user_id
  end

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
  validates :name, :description, :ticket_cost, :type, presence: true
  validates :ticket_cost, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :image, presence: true, on: :create

  has_many :shop_orders, dependent: :restrict_with_error

  def agh_contents=(value)
    if value.is_a?(String) && value.present?
      begin
        super(JSON.parse(value))
      rescue JSON::ParserError
        errors.add(:agh_contents, "is not valid JSON")
        super(nil)
      end
    else
      super(value)
    end
  end

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

    reserved_quantity = shop_orders.where(aasm_state: %w[pending awaiting_verification awaiting_periodical_fulfillment on_hold fulfilled]).sum(:quantity)
    stock - reserved_quantity
  end

  def out_of_stock?
    limited? && remaining_stock && remaining_stock <= 0
  end

  def available_accessories
    ShopItem::Accessory.where("? = ANY(attached_shop_item_ids)", id).where(enabled: true)
  end

  def has_accessories?
    available_accessories.exists?
  end

  private

  def carousel_relevant_change?
    show_in_carousel? || saved_change_to_show_in_carousel?
  end

  def refresh_carousel_cache
    Cache::CarouselPrizesJob.perform_later(force: true)
  end

  def invalidate_buyable_standalone_cache
    self.class.invalidate_buyable_standalone_cache!
  end
end
