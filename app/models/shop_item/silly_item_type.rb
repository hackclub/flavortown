class ShopItem::SillyItemType < ShopItem
  def fulfill!(shop_order)
    shop_order.mark_fulfilled!(nil, nil, "System")
  end
end
