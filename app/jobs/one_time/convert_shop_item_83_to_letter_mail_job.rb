class OneTime::ConvertShopItem83ToLetterMailJob < ApplicationJob
  queue_as :literally_whenever

  def perform
    item = ShopItem.find(83)
    item.update!(type: "ShopItem::LetterMail")
  end
end
