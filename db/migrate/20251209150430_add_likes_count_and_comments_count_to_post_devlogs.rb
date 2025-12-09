class AddLikesCountAndCommentsCountToPostDevlogs < ActiveRecord::Migration[8.1]
  def change
    add_column :post_devlogs, :likes_count, :integer, default: 0, null: false
    add_column :post_devlogs, :comments_count, :integer, default: 0, null: false
    remove_column :projects, :likes_count, :integer
    remove_column :projects, :comments_count, :integer
  end
end
