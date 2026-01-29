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
#  inkthreadable_config              :jsonb
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
#  required_ships_count              :integer          default(1)
#  required_ships_end_date           :date
#  required_ships_start_date         :date
#  requires_ship                     :boolean          default(FALSE)
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
require "test_helper"

class ShopItem::InkthreadableItemTest < ActiveSupport::TestCase
  setup do
    @inkthreadable_item = ShopItem::InkthreadableItem.new(
      name: "Test Inkthreadable Item",
      inkthreadable_config: {
        "pn" => "TST-001",
        "designs" => { "front" => "https://example.com/front.png", "back" => "https://example.com/back.png" },
        "shipping_method" => "express",
        "brand_name" => "TestBrand"
      }
    )
  end

  test "product_number returns the pn from config" do
    assert_equal "TST-001", @inkthreadable_item.product_number
  end

  test "product_number returns nil when config has no pn" do
    @inkthreadable_item.inkthreadable_config = {}
    assert_nil @inkthreadable_item.product_number
  end

  test "design_urls returns designs from config" do
    expected = { "front" => "https://example.com/front.png", "back" => "https://example.com/back.png" }
    assert_equal expected, @inkthreadable_item.design_urls
  end

  test "design_urls returns empty hash when config has no designs" do
    @inkthreadable_item.inkthreadable_config = {}
    assert_equal({}, @inkthreadable_item.design_urls)
  end

  test "design_urls returns empty hash when inkthreadable_config is nil" do
    @inkthreadable_item.inkthreadable_config = nil
    assert_equal({}, @inkthreadable_item.design_urls)
  end

  test "shipping_method returns value from config" do
    assert_equal "express", @inkthreadable_item.shipping_method
  end

  test "shipping_method defaults to regular when not in config" do
    @inkthreadable_item.inkthreadable_config = {}
    assert_equal "regular", @inkthreadable_item.shipping_method
  end

  test "shipping_method defaults to regular when inkthreadable_config is nil" do
    @inkthreadable_item.inkthreadable_config = nil
    assert_equal "regular", @inkthreadable_item.shipping_method
  end

  test "brand_name returns value from config" do
    assert_equal "TestBrand", @inkthreadable_item.brand_name
  end

  test "brand_name returns nil when not in config" do
    @inkthreadable_item.inkthreadable_config = {}
    assert_nil @inkthreadable_item.brand_name
  end

  test "inkthreadable_config returns empty hash when nil" do
    item = ShopItem::InkthreadableItem.new(name: "Test Item")
    assert_equal({}, item.inkthreadable_config)
  end

  test "fulfill! enqueues SendInkthreadableOrderJob and transitions order" do
    @inkthreadable_item.save!

    user = users(:one)
    order = ShopOrder.new(
      user: user,
      shop_item: @inkthreadable_item,
      quantity: 1,
      aasm_state: "pending",
      frozen_address: { "street" => "123 Test St", "city" => "Test City", "country" => "US" }
    )
    order.save!(validate: false)

    assert_enqueued_with(job: Shop::SendInkthreadableOrderJob, args: [ order.id ]) do
      @inkthreadable_item.fulfill!(order)
    end

    order.reload
    assert_equal "awaiting_periodical_fulfillment", order.aasm_state
  end
end
