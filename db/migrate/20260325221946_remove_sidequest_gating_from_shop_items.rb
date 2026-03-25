class RemoveSidequestGatingFromShopItems < ActiveRecord::Migration[8.1]
  def change
    remove_foreign_key :shop_items, :sidequests, column: :sidequest_id, if_exists: true
    remove_index :shop_items, :sidequest_id, if_exists: true
    safety_assured do
      remove_column :shop_items, :requires_sidequest_entry, :boolean, default: false, null: false
      remove_column :shop_items, :sidequest_approval_required, :boolean, default: true, null: false
      remove_column :shop_items, :sidequest_id, :bigint
    end
  end
end
