class RemoveDeletedAtFromPosts < ActiveRecord::Migration[8.1]
  def change
    remove_index :posts, :deleted_at, if_exists: true
    remove_column :posts, :deleted_at, :datetime, if_exists: true
  end
end
