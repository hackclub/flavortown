# frozen_string_literal: true

class Shop::UpdateHCBLocksJob < ApplicationJob
  queue_as :latency_10s

  def perform(shop_item_id)
    shop_item = ShopItem.find(shop_item_id)
    return unless shop_item.is_a?(ShopItem::HCBGrant) || shop_item.is_a?(ShopItem::HCBPreauthGrant)

    shop_item.shop_card_grants.each do |grant|
      next unless grant.hcb_grant_hashid

      begin
        Rails.logger.info "Updating HCB locks for grant #{grant.hcb_grant_hashid}"

        update_params = {
          hashid: grant.hcb_grant_hashid,
          merchant_lock: shop_item.hcb_merchant_lock,
          keyword_lock: shop_item.hcb_keyword_lock,
          category_lock: shop_item.hcb_category_lock,
          purpose: shop_item.name
        }

        if shop_item.is_a?(ShopItem::HCBPreauthGrant)
          update_params[:instructions] = shop_item.hcb_preauthorization_instructions
        end

        HCBService.update_card_grant(**update_params)
        Rails.logger.info "Successfully updated locks for grant #{grant.hcb_grant_hashid}"
      rescue => e
        Rails.logger.error "Failed to update HCB locks for grant #{grant.hcb_grant_hashid}: #{e.message}"
      end
    end
  end
end
