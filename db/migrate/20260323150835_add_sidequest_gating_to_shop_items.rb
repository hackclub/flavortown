class AddSidequestGatingToShopItems < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :shop_items, :requires_sidequest_entry, :boolean, default: false, null: false, if_not_exists: true
    add_column :shop_items, :sidequest_id, :bigint, null: true, if_not_exists: true
    add_column :shop_items, :sidequest_approval_required, :boolean, default: true, null: false, if_not_exists: true
    add_index :shop_items, :sidequest_id, algorithm: :concurrently, if_not_exists: true
    add_foreign_key :shop_items, :sidequests, column: :sidequest_id, validate: false
  end
end
