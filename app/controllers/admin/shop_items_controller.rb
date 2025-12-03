module Admin
  class ShopItemsController < Admin::ApplicationController
    before_action :set_shop_item, only: [ :show, :edit, :update, :destroy ]
    before_action :set_shop_item_types, only: [ :new, :edit ]

    def show
      authorize :admin, :manage_shop?
    end

    def new
      authorize :admin, :manage_shop?
      @shop_item = ShopItem.new
      Shop::Regionalizable::REGION_CODES.each do |code|
        @shop_item.public_send("enabled_#{code.downcase}=", true)
      end
    end

    def create
      authorize :admin, :manage_shop?
      @shop_item = ShopItem.new(shop_item_params)

      if @shop_item.save
        redirect_to admin_manage_shop_path, notice: "Shop item created successfully."
      else
        @shop_item_types = available_shop_item_types
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize :admin, :manage_shop?
    end

    def update
      authorize :admin, :manage_shop?

      if @shop_item.update(shop_item_params)
        redirect_to admin_shop_item_path(@shop_item), notice: "Shop item updated successfully."
      else
        @shop_item_types = available_shop_item_types
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize :admin, :manage_shop?
      @shop_item.destroy
      redirect_to admin_manage_shop_path, notice: "Shop item deleted successfully."
    end

    private

    def set_shop_item
      @shop_item = ShopItem.find(params[:id])
    end

    def set_shop_item_types
      @shop_item_types = available_shop_item_types
    end

    def available_shop_item_types
      [
        "ShopItem::HCBGrant",
        "ShopItem::HCBPreauthGrant",
        "ShopItem::HQMailItem",
        "ShopItem::LetterMail",
        "ShopItem::ThirdPartyPhysical",
        "ShopItem::WarehouseItem",
        "ShopItem::SpecialFulfillmentItem",
        "ShopItem::HackClubberItem",
        "ShopItem::FreeStickers"
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
        :enabled_uk,
        :enabled_in,
        :enabled_au,
        :enabled_xx,
        :price_offset_us,
        :price_offset_ca,
        :price_offset_eu,
        :price_offset_uk,
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
        :payout_percentage,
        :user_id,
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
