class AddUniquenessToPostsPostable < ActiveRecord::Migration[8.1]
  def change
    add_index :posts, [ :postable_type, :postable_id ], unique: true
  end
end
