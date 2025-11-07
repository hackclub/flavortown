module Admin
  class ShopItemsController < Admin::ApplicationController
    def new
      authorize :admin, :manage_shop?
      @shop_item = ShopItem.new
      @shop_item_types = available_shop_item_types
    end

    def create
      authorize :admin, :manage_shop?
      @shop_item = ShopItem.new(shop_item_params)

      if @shop_item.save
        redirect_to admin_manage_shop_path, notice: "Shop item created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize :admin, :manage_shop?
      @shop_item = ShopItem.find(params[:id])
      @shop_item_types = available_shop_item_types
    end

    def update
      authorize :admin, :manage_shop?
      @shop_item = ShopItem.find(params[:id])

      if @shop_item.update(shop_item_params)
        redirect_to admin_manage_shop_path, notice: "Shop item updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def available_shop_item_types
      [
        "ShopItem::HCBGrant",
        "ShopItem::HCBPreauthGrant",
        "ShopItem::HQMailItem",
        "ShopItem::LetterMail",
        "ShopItem::ThirdPartyPhysical",
        "ShopItem::WarehouseItem",
        "ShopItem::SpecialFulfillmentItem"
      ]
    end

    def shop_item_params
      params.require(:shop_item).permit(
        :name,
        :type,
        :description,
        :internal_description,
        :ticket_cost,
        :usd_cost,
        :enabled,
        :enabled_us,
        :enabled_ca,
        :enabled_eu,
        :enabled_in,
        :enabled_au,
        :enabled_xx,
        :price_offset_us,
        :price_offset_ca,
        :price_offset_eu,
        :price_offset_in,
        :price_offset_au,
        :price_offset_xx,
        :limited,
        :stock,
        :max_qty,
        :one_per_person_ever,
        :show_in_carousel,
        :special,
        :sale_percentage,
        :hacker_score,
        :unlock_on,
        :site_action,
        :hcb_category_lock,
        :hcb_keyword_lock,
        :hcb_merchant_lock,
        :hcb_preauthorization_instructions,
        :agh_contents,
        :image
      )
    end
  end
end
