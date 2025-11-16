# == Schema Information
#
# Table name: shop_items
#
#  id                                :bigint           not null, primary key
#  agh_contents                      :jsonb
#  description                       :string
#  enabled                           :boolean
#  enabled_au                        :boolean
#  enabled_ca                        :boolean
#  enabled_eu                        :boolean
#  enabled_in                        :boolean
#  enabled_us                        :boolean
#  enabled_xx                        :boolean
#  hacker_score                      :integer
#  hcb_category_lock                 :string
#  hcb_keyword_lock                  :string
#  hcb_merchant_lock                 :string
#  hcb_preauthorization_instructions :text
#  internal_description              :string
#  limited                           :boolean
#  max_qty                           :integer
#  name                              :string
#  one_per_person_ever               :boolean
#  price_offset_au                   :decimal(, )
#  price_offset_ca                   :decimal(, )
#  price_offset_eu                   :decimal(, )
#  price_offset_in                   :decimal(, )
#  price_offset_us                   :decimal(, )
#  price_offset_xx                   :decimal(, )
#  sale_percentage                   :integer
#  show_in_carousel                  :boolean
#  site_action                       :integer
#  special                           :boolean
#  stock                             :integer
#  ticket_cost                       :decimal(, )
#  type                              :string
#  unlock_on                         :date
#  usd_cost                          :decimal(, )
#  created_at                        :datetime         not null
#  updated_at                        :datetime         not null
#
class ShopItem::WarehouseItem < ShopItem
  # Normalizes per-unit ship spec; supports keys like qty/quantity
  def per_unit_contents
    contents_array = agh_contents.is_a?(Array) ? agh_contents : (agh_contents.presence || [])
    contents_array.map do |row|
      {
        "sku" => row["sku"] || row["id"] || row["name"],
        "name" => row["name"],
        "qty" => (row["qty"] || row["quantity"] || 1).to_i
      }
    end
  end

  # Multiplies spec by ordered quantity
  def contents_for_order_qty(order_qty)
    per_unit_contents.map { |r| r.merge("qty" => r["qty"] * order_qty.to_i) }
  end
end
