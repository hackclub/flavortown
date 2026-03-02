class AddRequiresVerificationCallToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :requires_verification_call, :boolean, default: false, null: false
  end
end
