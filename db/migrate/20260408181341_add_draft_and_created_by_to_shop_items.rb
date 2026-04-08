class AddDraftAndCreatedByToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shop_items, :draft, :boolean, default: false, null: false
    add_column :shop_items, :created_by_user_id, :bigint
    add_foreign_key :shop_items, :users, column: :created_by_user_id, on_delete: :nullify, validate: false
  end
end
