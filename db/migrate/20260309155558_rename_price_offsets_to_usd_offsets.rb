class RenamePriceOffsetsToUsdOffsets < ActiveRecord::Migration[8.1]
  TICKETS_PER_DOLLAR = 5.0
  REGION_CODES = %w[us ca eu uk in au xx].freeze

  class ShopItem < ActiveRecord::Base
    self.table_name = "shop_items"
    self.inheritance_column = :_type_disabled
  end

  def up
    REGION_CODES.each do |code|
      add_column :shop_items, "usd_offset_#{code}", :decimal, precision: 10, scale: 2
    end

    ShopItem.reset_column_information

    ShopItem.find_each do |item|
      hacker_score = item.hacker_score || 50
      multiplier = TICKETS_PER_DOLLAR * (0.5 + (1.0 - hacker_score / 100.0))

      updates = {}
      REGION_CODES.each do |code|
        old_val = item.send("price_offset_#{code}")
        updates["usd_offset_#{code}"] = old_val / multiplier if old_val.present?
      end

      item.update_columns(updates) if updates.any?
    end

    safety_assured do
      REGION_CODES.each do |code|
        remove_column :shop_items, "price_offset_#{code}"
      end
    end
  end

  def down
    REGION_CODES.each do |code|
      add_column :shop_items, "price_offset_#{code}", :decimal, precision: 10, scale: 2
    end

    ShopItem.reset_column_information

    ShopItem.find_each do |item|
      hacker_score = item.hacker_score || 50
      multiplier = TICKETS_PER_DOLLAR * (0.5 + (1.0 - hacker_score / 100.0))

      updates = {}
      REGION_CODES.each do |code|
        usd_val = item.send("usd_offset_#{code}")
        updates["price_offset_#{code}"] = usd_val * multiplier if usd_val.present?
      end

      item.update_columns(updates) if updates.any?
    end

    REGION_CODES.each do |code|
      remove_column :shop_items, "usd_offset_#{code}"
    end
  end
end
