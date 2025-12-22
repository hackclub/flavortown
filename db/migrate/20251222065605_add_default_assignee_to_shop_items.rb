class AddDefaultAssigneeToShopItems < ActiveRecord::Migration[8.1]
  def change
    add_reference :shop_items, :default_assignee, foreign_key: { to_table: :users }, null: true
  end
end
