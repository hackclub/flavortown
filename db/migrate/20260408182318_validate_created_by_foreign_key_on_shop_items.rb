class ValidateCreatedByForeignKeyOnShopItems < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :shop_items, :created_by_user_id, algorithm: :concurrently
    validate_foreign_key :shop_items, :users
  end
end
