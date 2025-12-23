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
class ShopItem::HCBGrant < ShopItem
  after_save :enqueue_hcb_locks_update, if: :hcb_locks_changed?

  has_many :shop_card_grants, through: :shop_orders
  def fulfill!(shop_order)
    amount_cents = (usd_cost * shop_order.quantity * 100).to_i
    email = shop_order.user.grant_email
    merchant_lock = hcb_merchant_lock
    keyword_lock = hcb_keyword_lock
    category_lock = hcb_category_lock

    grant_rec = ShopCardGrant.find_or_initialize_by(
      user: shop_order.user,
      shop_item: self
    )

    user_canceled = false
    latest_disbursement = nil
    memo = nil

    grant_rec.transaction do
      begin
        if grant_rec.new_record? || user_canceled
            # Create new grant
            Rails.logger.info "Creating new #{amount_cents}¢ HCB grant for #{email}"

            grant_res = HCBService.create_card_grant(
              email: email,
              amount_cents: amount_cents,
              merchant_lock: merchant_lock,
              keyword_lock: keyword_lock,
              category_lock: category_lock,
              purpose: name
            )

            grant_rec.hcb_grant_hashid = grant_res["id"]
            grant_rec.expected_amount_cents = amount_cents
            grant_rec.save!

            latest_disbursement = grant_res.dig("disbursements", 0, "transaction_id")
            memo = "[grant] #{name} for #{shop_order.user.display_name}"
        else
          hashid = grant_rec.hcb_grant_hashid

          begin
            hcb_grant = HCBService.show_card_grant(hashid: hashid)
            if hcb_grant["status"] == "canceled"
              user_canceled = true
              raise StandardError, "Grant canceled"
            end
          rescue => e
            Rails.logger.error "Error checking grant status: #{e.message}"
            user_canceled = true
            raise StandardError, "Grant canceled"
          end

          Rails.logger.info "Topping up #{hashid} by #{amount_cents}¢"
          topup_res = HCBService.topup_card_grant(
            hashid: hashid,
            amount_cents: amount_cents
          )

          latest_disbursement = topup_res.dig("disbursements", 0, "transaction_id")
          grant_rec.expected_amount_cents = (grant_rec.expected_amount_cents || 0) + amount_cents
          grant_rec.save!

          memo = "[grant] topping up #{shop_order.user.display_name}'s #{name}"
        end

      Rails.logger.info "Got disbursement #{latest_disbursement}"
      rescue => e
        if user_canceled
          Rails.logger.info "Grant was canceled, creating new grant"
          grant_rec = ShopCardGrant.new(user: shop_order.user, shop_item: self)
          user_canceled = false
          retry
        else
          raise e
        end
      end
    end

    # add card grant to shop order
    shop_order.shop_card_grant = grant_rec
    shop_order.mark_fulfilled! "SCG #{grant_rec.id}", nil, "System"

    # Rename transaction
    if latest_disbursement && memo
      begin
        HCBService.rename_transaction(
          hashid: latest_disbursement,
          new_memo: memo
        )
      rescue => e
        Rails.logger.error "Couldn't rename transaction #{latest_disbursement}: #{e.message}"
      end
    end

    grant_rec
  end

  private
  def hcb_locks_changed?
    type == "ShopItem::HCBGrant" &&
      saved_change_to_hcb_merchant_lock? ||
      saved_change_to_hcb_keyword_lock? ||
      saved_change_to_hcb_category_lock?
  end

  def enqueue_hcb_locks_update
    Shop::UpdateHCBLocksJob.perform_later(id)
  end
end
