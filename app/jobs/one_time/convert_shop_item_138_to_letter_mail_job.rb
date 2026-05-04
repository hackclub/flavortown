class OneTime::ConvertShopItem138ToLetterMailJob < ApplicationJob
  queue_as :literally_whenever

  def perform
    item = ShopItem.find(138)
    item.update!(type: "ShopItem::LetterMail")
  end
end
