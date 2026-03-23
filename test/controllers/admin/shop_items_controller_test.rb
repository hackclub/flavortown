require "test_helper"

module Admin
  class ShopItemsControllerTest < ActionDispatch::IntegrationTest
    test "available_shop_item_types includes SillyItemType" do
      controller = Admin::ShopItemsController.new
      types = controller.send(:available_shop_item_types)

      assert_includes types, "ShopItem::SillyItemType"
    end

    test "available_shop_item_types includes all expected types" do
      controller = Admin::ShopItemsController.new
      types = controller.send(:available_shop_item_types)

      expected_types = %w[
        ShopItem::Accessory
        ShopItem::HCBGrant
        ShopItem::HCBPreauthGrant
        ShopItem::HQMailItem
        ShopItem::LetterMail
        ShopItem::ThirdPartyPhysical
        ShopItem::ThirdPartyDigital
        ShopItem::WarehouseItem
        ShopItem::SpecialFulfillmentItem
        ShopItem::HackClubberItem
        ShopItem::FreeStickers
        ShopItem::PileOfStickersItem
        ShopItem::SillyItemType
      ]

      expected_types.each do |type|
        assert_includes types, type, "Expected types to include #{type}"
      end
    end
  end
end
