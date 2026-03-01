class ShopItemCardComponent < ViewComponent::Base
  include MarkdownHelper

  attr_reader :item_id, :name, :description, :hours, :price, :image_url, :item_type, :balance, :enabled_regions, :regional_price, :logged_in, :remaining_stock, :limited, :on_sale, :sale_percentage, :original_price, :created_at, :show_bow, :show_time_ago, :purchase_count, :is_new, :enabled_until

  def initialize(item_id:, name:, description:, hours:, price:, image_url:, item_type: nil, balance: nil, enabled_regions: [], regional_price: nil, logged_in: true, remaining_stock: nil, limited: false, on_sale: false, sale_percentage: nil, original_price: nil, created_at: nil, show_bow: false, show_time_ago: false, purchase_count: nil, is_new: false, enabled_until: nil)
    @item_id = item_id
    @name = name
    @description = description
    @hours = hours
    @price = price
    @image_url = image_url
    @item_type = item_type
    @balance = balance
    @enabled_regions = enabled_regions
    @regional_price = regional_price || price
    @logged_in = logged_in
    @remaining_stock = remaining_stock
    @limited = limited
    @on_sale = on_sale
    @sale_percentage = sale_percentage
    @original_price = original_price
    @created_at = created_at
    @show_bow = show_bow
    @show_time_ago = show_time_ago
    @purchase_count = purchase_count
    @is_new = is_new
    @enabled_until = enabled_until
  end

  def time_ago_text
    return nil unless created_at && show_time_ago
    helpers.time_ago_in_words(created_at) + " ago"
  end

  def order_url
    logged_in ? "/shop/order?shop_item_id=#{item_id}" : "/"
  end

  def display_price
    @regional_price
  end

  def categories
    return [] unless item_type
    cats = []
    case item_type
    when "ShopItem::HCBGrant", "ShopItem::HCBPreauthGrant"
      cats << "Grants" << "Digital"
    when "ShopItem::WarehouseItem", "ShopItem::HQMailItem", "ShopItem::LetterMail", "ShopItem::FreeStickers", "ShopItem::PileOfStickersItem"
      cats << "HQ"
    when "ShopItem::ThirdPartyDigital"
      cats << "Digital"
    when "ShopItem::ThirdPartyPhysical", "ShopItem::SpecialFulfillmentItem"
      cats << "Locally Fulfilled"
    when "ShopItem::HackClubberItem"
      cats << "Made by Hack Clubbers"
    end
    cats
  end

  def out_of_stock?
    limited && remaining_stock.present? && remaining_stock <= 0
  end

  def low_stock?
    limited && remaining_stock.present? && remaining_stock > 0 && remaining_stock <= 5
  end

  def show_stock_indicator?
    limited && remaining_stock.present?
  end
end
