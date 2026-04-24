require "test_helper"

# Pure unit tests for ShopItemCardComponent display logic
class ShopItemCardComponentTest < Minitest::Test
  def test_primary_highlight_with_purchase_count
    component = ShopItemCardComponent.new(
      item_id: 1,
      name: "Test Item",
      description: "Test",
      hours: 5,
      price: 100,
      image_url: "image.png",
      purchase_count: 25
    )

    highlight = component.primary_highlight
    assert_equal :bought, highlight[:type]
    assert_equal "25 bought", highlight[:text]
    assert component.show_primary_highlight?
  end

  def test_primary_highlight_with_new_flag
    component = ShopItemCardComponent.new(
      item_id: 1,
      name: "Test Item",
      description: "Test",
      hours: 5,
      price: 100,
      image_url: "image.png",
      is_new: true
    )

    highlight = component.primary_highlight
    assert_equal :new, highlight[:type]
    assert_equal "New", highlight[:text]
    assert component.show_primary_highlight?
  end

  def test_primary_highlight_priority_bought_over_new
    component = ShopItemCardComponent.new(
      item_id: 1,
      name: "Test Item",
      description: "Test",
      hours: 5,
      price: 100,
      image_url: "image.png",
      purchase_count: 10,
      is_new: true
    )

    highlight = component.primary_highlight
    assert_equal :bought, highlight[:type], "bought count should take priority over new"
  end

  def test_no_primary_highlight_without_flags
    component = ShopItemCardComponent.new(
      item_id: 1,
      name: "Test Item",
      description: "Test",
      hours: 5,
      price: 100,
      image_url: "image.png"
    )

    assert_nil component.primary_highlight
    refute component.show_primary_highlight?
  end

  def test_secondary_highlight_limited_stock
    enabled_until = 2.days.from_now
    component = ShopItemCardComponent.new(
      item_id: 1,
      name: "Test Item",
      description: "Test",
      hours: 5,
      price: 100,
      image_url: "image.png",
      enabled_until: enabled_until
    )

    highlight = component.secondary_highlight
    assert_equal :limited, highlight[:type]
    assert_equal "Limited Stock", highlight[:label]
    assert highlight[:text].include?("left"), "timer text should include 'left'"
    assert component.show_secondary_highlight?
  end

  def test_no_secondary_highlight_when_purchased
    component = ShopItemCardComponent.new(
      item_id: 1,
      name: "Test Item",
      description: "Test",
      hours: 5,
      price: 100,
      image_url: "image.png",
      purchase_count: 5,
      enabled_until: 2.days.from_now
    )

    # Secondary highlight should only show if there's no primary highlight
    assert_nil component.secondary_highlight,
               "Secondary highlight should not show when primary is :bought"
  end

  def test_stock_status_out_of_stock
    component = ShopItemCardComponent.new(
      item_id: 1,
      name: "Test Item",
      description: "Test",
      hours: 5,
      price: 100,
      image_url: "image.png",
      limited: true,
      remaining_stock: 0
    )

    assert_equal "Out of stock", component.stock_status_text
    assert component.show_stock_status?
  end

  def test_stock_status_low_stock
    component = ShopItemCardComponent.new(
      item_id: 1,
      name: "Test Item",
      description: "Test",
      hours: 5,
      price: 100,
      image_url: "image.png",
      limited: true,
      remaining_stock: 3
    )

    assert_equal "3 left", component.stock_status_text
    assert component.show_stock_status?
  end

  def test_stock_status_critical_when_below_three
    component = ShopItemCardComponent.new(
      item_id: 1,
      name: "Test Item",
      description: "Test",
      hours: 5,
      price: 100,
      image_url: "image.png",
      limited: true,
      remaining_stock: 2
    )

    assert_equal "2 left", component.stock_status_text
    assert component.critical_stock?
    assert_equal "shop-item-card__stock-meta--critical", component.stock_status_class
  end

  def test_stock_status_normal_stock
    component = ShopItemCardComponent.new(
      item_id: 1,
      name: "Test Item",
      description: "Test",
      hours: 5,
      price: 100,
      image_url: "image.png",
      limited: true,
      remaining_stock: 20
    )

    assert_nil component.stock_status_text, "Should not show status for normal stock levels"
    refute component.show_stock_status?
  end

  def test_stock_status_unlimited_item
    component = ShopItemCardComponent.new(
      item_id: 1,
      name: "Test Item",
      description: "Test",
      hours: 5,
      price: 100,
      image_url: "image.png",
      limited: false,
      remaining_stock: nil
    )

    assert_nil component.stock_status_text
    refute component.show_stock_status?
  end

  def test_sale_percentage_text
    component = ShopItemCardComponent.new(
      item_id: 1,
      name: "Test Item",
      description: "Test",
      hours: 5,
      price: 100,
      image_url: "image.png",
      on_sale: true,
      sale_percentage: 25
    )

    assert_equal "25% OFF", component.sale_percentage_text
    assert component.show_sale_badge?
  end

  def test_no_sale_badge_when_not_on_sale
    component = ShopItemCardComponent.new(
      item_id: 1,
      name: "Test Item",
      description: "Test",
      hours: 5,
      price: 100,
      image_url: "image.png",
      on_sale: false,
      sale_percentage: 25
    )

    assert_nil component.sale_percentage_text
    refute component.show_sale_badge?
  end

  def test_out_of_stock_predicate
    component = ShopItemCardComponent.new(
      item_id: 1,
      name: "Test Item",
      description: "Test",
      hours: 5,
      price: 100,
      image_url: "image.png",
      limited: true,
      remaining_stock: 0
    )

    assert component.out_of_stock?
  end

  def test_low_stock_predicate
    component = ShopItemCardComponent.new(
      item_id: 1,
      name: "Test Item",
      description: "Test",
      hours: 5,
      price: 100,
      image_url: "image.png",
      limited: true,
      remaining_stock: 4
    )

    assert component.low_stock?
  end

  def test_show_stock_indicator_threshold
    component_at_threshold = ShopItemCardComponent.new(
      item_id: 1,
      name: "Test Item",
      description: "Test",
      hours: 5,
      price: 100,
      image_url: "image.png",
      limited: true,
      remaining_stock: 10
    )
    assert component_at_threshold.show_stock_indicator?,
           "Should show stock indicator at 10 or below"

    component_above_threshold = ShopItemCardComponent.new(
      item_id: 1,
      name: "Test Item",
      description: "Test",
      hours: 5,
      price: 100,
      image_url: "image.png",
      limited: true,
      remaining_stock: 11
    )
    refute component_above_threshold.show_stock_indicator?,
           "Should not show stock indicator above 10"
  end

  def test_limited_stock_timer_countdown_text
    enabled_until = 2.hours.from_now
    component = ShopItemCardComponent.new(
      item_id: 1,
      name: "Test Item",
      description: "Test",
      hours: 5,
      price: 100,
      image_url: "image.png",
      enabled_until: enabled_until
    )

    timer_text = component.limited_stock_timer_text
    assert timer_text.include?("h"), "Timer text should include hours"
    assert timer_text.include?("left"), "Timer text should include 'left'"
  end

  def test_combined_scenario_new_with_limited_timer
    enabled_until = 3.hours.from_now
    component = ShopItemCardComponent.new(
      item_id: 1,
      name: "Test Item",
      description: "Test",
      hours: 5,
      price: 100,
      image_url: "image.png",
      is_new: true,
      enabled_until: enabled_until
    )

    primary = component.primary_highlight
    secondary = component.secondary_highlight

    assert_equal :new, primary[:type]
    assert_nil secondary, "Secondary should not show when primary exists"
  end

  def test_combined_scenario_purchased_with_low_stock
    component = ShopItemCardComponent.new(
      item_id: 1,
      name: "Test Item",
      description: "Test",
      hours: 5,
      price: 100,
      image_url: "image.png",
      purchase_count: 15,
      limited: true,
      remaining_stock: 2
    )

    assert_equal :bought, component.primary_highlight[:type]
    assert_equal "2 left", component.stock_status_text
    assert component.low_stock?
  end
end
