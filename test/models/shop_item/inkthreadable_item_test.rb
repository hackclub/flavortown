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
