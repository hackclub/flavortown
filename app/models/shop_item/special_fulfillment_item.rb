# == Schema Information
#
# Table name: shop_items
#
#  id                                :bigint           not null, primary key
#  accessory_tag                     :string
#  agh_contents                      :jsonb
#  attached_shop_item_ids            :bigint           default([]), is an Array
#  buyable_by_self                   :boolean          default(TRUE)
#  default_assigned_user_id_au       :bigint
#  default_assigned_user_id_ca       :bigint
#  default_assigned_user_id_eu       :bigint
#  default_assigned_user_id_in       :bigint
#  default_assigned_user_id_uk       :bigint
#  default_assigned_user_id_us       :bigint
#  default_assigned_user_id_xx       :bigint
#  description                       :string
#  enabled                           :boolean
#  enabled_au                        :boolean
#  enabled_ca                        :boolean
#  enabled_eu                        :boolean
#  enabled_in                        :boolean
#  enabled_uk                        :boolean
#  enabled_us                        :boolean
#  enabled_xx                        :boolean
#  hacker_score                      :integer
#  hcb_category_lock                 :string
#  hcb_keyword_lock                  :string
#  hcb_merchant_lock                 :string
#  hcb_preauthorization_instructions :text
#  internal_description              :string
#  limited                           :boolean
#  long_description                  :text
#  max_qty                           :integer
#  name                              :string
#  old_prices                        :integer          default([]), is an Array
#  one_per_person_ever               :boolean
#  payout_percentage                 :integer          default(0)
#  price_offset_au                   :decimal(, )
#  price_offset_ca                   :decimal(, )
#  price_offset_eu                   :decimal(, )
#  price_offset_in                   :decimal(, )
#  price_offset_uk                   :decimal(10, 2)
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
#  default_assigned_user_id          :bigint
#  user_id                           :bigint
#
# Indexes
#
#  index_shop_items_on_default_assigned_user_id  (default_assigned_user_id)
#  index_shop_items_on_user_id                   (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (default_assigned_user_id => users.id) ON DELETE => nullify
#  fk_rails_...  (user_id => users.id)
#
class ShopItem::SpecialFulfillmentItem < ShopItem
end
