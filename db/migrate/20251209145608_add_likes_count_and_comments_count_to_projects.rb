class AddLikesCountAndCommentsCountToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :likes_count, :integer, default: 0, null: false
    add_column :projects, :comments_count, :integer, default: 0, null: false
  end
end
