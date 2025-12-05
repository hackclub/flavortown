# == Schema Information
#
# Table name: shop_orders
#
#  id                                 :bigint           not null, primary key
#  aasm_state                         :string
#  awaiting_periodical_fulfillment_at :datetime
#  external_ref                       :string
#  frozen_address_ciphertext          :text
#  frozen_item_price                  :decimal(6, 2)
#  fulfilled_at                       :datetime
#  fulfilled_by                       :string
#  fulfillment_cost                   :decimal(6, 2)    default(0.0)
#  internal_notes                     :text
#  on_hold_at                         :datetime
#  quantity                           :integer
#  rejected_at                        :datetime
#  rejection_reason                   :string
#  tracking_number                    :string
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  shop_card_grant_id                 :bigint
#  shop_item_id                       :bigint           not null
#  user_id                            :bigint           not null
#  warehouse_package_id               :bigint
#
# Indexes
#
#  idx_shop_orders_item_state_qty     (shop_item_id,aasm_state,quantity)
#  idx_shop_orders_stock_calc         (shop_item_id,aasm_state)
#  idx_shop_orders_user_item_state    (user_id,shop_item_id,aasm_state)
#  idx_shop_orders_user_item_unique   (user_id,shop_item_id)
#  index_shop_orders_on_shop_item_id  (shop_item_id)
#  index_shop_orders_on_user_id       (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (shop_item_id => shop_items.id)
#  fk_rails_...  (user_id => users.id)
#
class ShopOrder < ApplicationRecord
  has_paper_trail ignore: [ :frozen_address_ciphertext ]

  include AASM
  include Ledgerable

  belongs_to :user
  belongs_to :shop_item
  belongs_to :shop_card_grant, optional: true

  # has_many :payouts, as: :payable, dependent: :destroy

  # Encrypt frozen_address using Lockbox
  has_encrypted :frozen_address, type: :json

  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }, on: :create
  validate :check_one_per_person_ever_limit, on: :create
  validate :check_max_quantity_limit, on: :create
  validate :check_user_balance, on: :create
  validate :check_regional_availability, on: :create
  validate :check_free_stickers_requirement, on: :create

  after_create :create_negative_payout
  before_create :freeze_item_price

  scope :worth_counting, -> { where.not(aasm_state: %w[rejected refunded]) }
  scope :manually_fulfilled, -> { joins(:shop_item).merge(ShopItem.where(type: ShopItem::MANUAL_FULFILLMENT_TYPES)) }
  scope :with_item_type, ->(item_type) { joins(:shop_item).where(shop_items: { type: item_type.to_s }) }
  scope :without_item_type, ->(item_type) { joins(:shop_item).where.not(shop_items: { type: item_type.to_s }) }

  DIGITAL_FULFILLMENT_TYPES = %w[
    ShopItem::HCBGrant
    ShopItem::HCBPreauthGrant
    ShopItem::ThirdPartyDigital
    ShopItem::SpecialFulfillmentItem
    ShopItem::WarehouseItem
    ShopItem::FreeStickers
  ].freeze

  def full_name
    "#{user.display_name}'s order for #{quantity} #{shop_item.name.pluralize(quantity)}"
  end

  def can_view_address?(viewer)
    return false unless viewer
    return false if DIGITAL_FULFILLMENT_TYPES.include?(shop_item.type)

    return true if viewer.admin?

    # Fulfillment person can only see addresses in their region
    if viewer.fulfillment_person? && frozen_address.present?
      order_region = Shop::Regionalizable.country_to_region(frozen_address["country"])
      # For now, we assume fulfillment persons can see all regions
      # You can add user region preferences later
      return true
    end

    false
  end

  def decrypted_address_for(viewer)
    return nil unless can_view_address?(viewer)

    # Log the access
    PaperTrail::Version.create!(
      item_type: "ShopOrder",
      item_id: id,
      event: "address_access",
      whodunnit: viewer.id,
      object_changes: {
        accessed_at: Time.current,
        user_id: viewer.id,
        order_id: id,
        reason: "address_decryption"
      }.to_yaml
    )

    frozen_address
  end

  def warehouse_pick_lines
    return [] unless shop_item.is_a?(ShopItem::WarehouseItem)
    shop_item.contents_for_order_qty(quantity || 1)
  end

  # Class method to get combined pick lines for a batch of orders (by warehouse_package_id)
  def self.combined_pick_lines_for_package(package_id)
    lines = Hash.new { |h, k| h[k] = { "sku" => k, "name" => nil, "qty" => 0 } }
    where(warehouse_package_id: package_id).includes(:shop_item).each do |order|
      order.warehouse_pick_lines.each do |line|
        entry = lines[line["sku"]]
        entry["name"] ||= line["name"]
        entry["qty"] += line["qty"].to_i
      end
    end
    lines.values
  end

  aasm timestamps: true do
    # Normal states
    state :pending, initial: true
    state :awaiting_periodical_fulfillment
    state :fulfilled

    # Exception states
    state :rejected
    state :on_hold
    state :refunded

    event :queue_for_fulfillment do
      transitions from: :pending, to: :awaiting_periodical_fulfillment
    end

    event :mark_rejected do
      transitions from: %i[pending awaiting_periodical_fulfillment], to: :rejected
      before do |rejection_reason|
        self.rejection_reason = rejection_reason
      end
      after do
        create_refund_payout
      end
    end

    event :mark_fulfilled do
      transitions to: :fulfilled
      before do |external_ref = nil, fulfillment_cost = nil, fulfilled_by = nil|
        self.external_ref = external_ref
        self.fulfillment_cost = fulfillment_cost if fulfillment_cost
        self.fulfilled_by = fulfilled_by if fulfilled_by
      end
      after do
        mark_stickers_received if shop_item.is_a?(ShopItem::FreeStickers)
      end
    end

    event :place_on_hold do
      transitions from: %i[pending awaiting_periodical_fulfillment], to: :on_hold
    end

    event :take_off_hold do
      transitions from: :on_hold, to: :pending
    end

    event :refund do
      transitions from: %i[pending awaiting_periodical_fulfillment fulfilled], to: :refunded
      after do
        create_refund_payout
      end
    end
  end

  def total_cost
    frozen_item_price * quantity
  end

  def approve!
    shop_item.fulfill!(self) if shop_item.respond_to?(:fulfill!)
  end

  def mark_stickers_received
    user.update(has_gotten_free_stickers: true)
  end

  private

  def freeze_item_price
    self.frozen_item_price ||= shop_item.ticket_cost if shop_item
  end

  def check_one_per_person_ever_limit
    return unless shop_item&.one_per_person_ever?

    if quantity && quantity > 1
      errors.add(:quantity, "can only be 1 for #{shop_item.name} (once per person item).")
      return
    end

    existing_order = user.shop_orders.joins(:shop_item).where(shop_item: shop_item).worth_counting
    existing_order = existing_order.where.not(id: id) if persisted?

    if existing_order.exists?
      errors.add(:base, "You can only order #{shop_item.name} once per person.")
    end
  end

  def check_max_quantity_limit
    return unless shop_item&.max_qty && quantity

    if quantity > shop_item.max_qty
      errors.add(:quantity, "cannot exceed #{shop_item.max_qty} for this item.")
    end
  end

  def check_user_balance
    return unless frozen_item_price&.positive? && quantity.present?

    total_cost_for_validation = frozen_item_price * quantity
    if user&.balance&.< total_cost_for_validation
      shortage = total_cost_for_validation - (user.balance || 0)
      errors.add(:base, "Insufficient balance. You need #{shortage} more tickets.")
    end
  end

  def check_regional_availability
    return unless shop_item.present? && frozen_address.present?

    address_country = frozen_address["country"]
    return unless address_country.present?

    address_region = Shop::Regionalizable.country_to_region(address_country)

    # Allow items enabled for the address region OR for XX (Rest of World)
    unless shop_item.enabled_in_region?(address_region) || shop_item.enabled_in_region?("XX")
      errors.add(:base, "This item is not available for shipping to #{address_country}.")
    end
  end

  def check_free_stickers_requirement
    return if user&.has_gotten_free_stickers?
    return if shop_item.is_a?(ShopItem::FreeStickers)

    errors.add(:base, "You must order the Free Stickers first before ordering other items!")
  end

  def create_negative_payout
    return unless frozen_item_price.present? && frozen_item_price > 0 && quantity.present?
    return unless user.respond_to?(:payouts)

    user.payouts.create!(
      amount: -total_cost,
      payable: self,
      reason: "Shop order of #{shop_item.name.pluralize(quantity)}"
    )
  end

  def create_refund_payout
    return unless frozen_item_price.present? && frozen_item_price > 0 && quantity.present?

    ledger_entries.create!(
      amount: total_cost,
      reason: "Refund for rejected order of #{shop_item.name.pluralize(quantity)}",
      created_by: user
    )
  end
end
