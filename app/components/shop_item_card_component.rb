class ShopItemCardComponent < ViewComponent::Base
  include MarkdownHelper

  attr_reader :item_id, :name, :description, :hours, :price, :image_url, :item_type, :balance, :enabled_regions, :regional_price, :logged_in, :remaining_stock, :limited, :on_sale, :sale_percentage, :original_price, :created_at, :show_bow, :show_time_ago, :purchase_count, :is_new, :enabled_until, :locked_by_achievement, :required_achievement_names, :required_achievement_hints

  def initialize(item_id:, name:, description:, hours:, price:, image_url:, item_type: nil, balance: nil, enabled_regions: [], regional_price: nil, logged_in: true, remaining_stock: nil, limited: false, on_sale: false, sale_percentage: nil, original_price: nil, created_at: nil, show_bow: false, show_time_ago: false, purchase_count: nil, is_new: false, enabled_until: nil, locked_by_achievement: false, required_achievement_names: [], required_achievement_hints: [])
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
    @locked_by_achievement = locked_by_achievement
    @required_achievement_names = required_achievement_names
    @required_achievement_hints = required_achievement_hints
  end

  def lock_overlay_html
    return "".html_safe unless locked_by_achievement

    helpers.content_tag(:div, "🔒", class: "shop-item-card__lock-overlay")
  end

  def achievement_requirement_html
    return "".html_safe unless locked_by_achievement && required_achievement_names.any?

    sentence = required_achievement_names.to_sentence(two_words_connector: " or ", last_word_connector: ", or ")
    children = [ helpers.content_tag(:div, "Requires: #{sentence}", class: "shop-item-card__achievement-names") ]
    if required_achievement_hints.any?
      children << helpers.content_tag(:div, required_achievement_hints.first, class: "shop-item-card__achievement-hints")
    end
    helpers.content_tag(:div, helpers.safe_join(children), class: "shop-item-card__achievement-requirement")
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
    limited && remaining_stock.present? && remaining_stock <= 10
  end

  def critical_stock?
    limited && remaining_stock.present? && remaining_stock > 0 && remaining_stock < 3
  end

  def show_limited_stock_timer?
    enabled_until.present?
  end

  def limited_stock_timer_text
    return nil unless enabled_until.present?

    seconds_left = (enabled_until.to_time - Time.current).to_i
    return "Ending soon" if seconds_left <= 0

    days = seconds_left / 1.day
    hours = (seconds_left % 1.day) / 1.hour
    minutes = (seconds_left % 1.hour) / 1.minute

    if days.positive?
      "#{days}d #{hours}h left"
    elsif hours.positive?
      "#{hours}h #{minutes}m left"
    else
      "#{[ minutes, 1 ].max}m left"
    end
  end

  # X bought > New > Limited

  def primary_highlight
    return { type: :bought, text: "#{purchase_count} bought" } if purchase_count.present?
    return { type: :new, text: "New" } if is_new
    nil
  end

  def show_primary_highlight?
    primary_highlight.present?
  end

  def secondary_highlight
    return nil if primary_highlight.present?
    return { type: :limited, text: limited_stock_timer_text, label: "Limited Stock" } if enabled_until.present?
    nil
  end

  def show_secondary_highlight?
    secondary_highlight.present?
  end

  def stock_status_text
    return "Out of stock" if out_of_stock?
    return "#{remaining_stock} left" if show_stock_indicator?
    nil
  end

  def show_stock_status?
    stock_status_text.present?
  end

  def sale_percentage_text
    return "#{sale_percentage}% OFF" if on_sale && sale_percentage.present?
    nil
  end

  def show_sale_badge?
    on_sale && sale_percentage.present?
  end

  def stock_status_class
    return "shop-item-card__stock-meta--critical" if critical_stock?

    nil
  end
end
