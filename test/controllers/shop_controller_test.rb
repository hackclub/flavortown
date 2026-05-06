require "test_helper"

class ShopControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @user = users(:one)
  end

  teardown do
    travel_back
    Flipper.disable(:shop_open)
  end

  test "shop index shows the scheduled closure countdown while open" do
    travel_to Time.utc(2026, 5, 6, 16, 0, 0) do
      Flipper.enable(:shop_open)

      get shop_path

      assert_response :success
      assert_includes response.body, "The shop closes Saturday, May 9 at 12:00 AM ET."
      assert_includes response.body, %(data-countdown-date-value="2026-05-09T00:00:00-04:00")
    end
  end

  test "shop order page redirects when the global shop flag is off" do
    sign_in(@user)
    Flipper.disable(:shop_open)

    get shop_order_path(shop_item_id: 999_999)

    assert_redirected_to shop_path
    follow_redirect!
    assert_includes response.body, "The shop is closed right now."
  end

  test "shop order creation redirects when the global shop flag is off" do
    sign_in(@user)
    Flipper.disable(:shop_open)

    post shop_order_path, params: { shop_item_id: 999_999, quantity: 1 }

    assert_redirected_to shop_path
    assert_equal "The shop is currently closed.", flash[:alert]
  end
end
