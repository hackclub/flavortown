class ChangePostableIdToBigintOnPosts < ActiveRecord::Migration[8.1]
  def up
    change_column :posts, :postable_id, :bigint, using: "postable_id::bigint"
  end

  def down
    change_column :posts, :postable_id, :string
  end
end
