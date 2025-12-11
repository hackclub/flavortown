class AddDeletedAtToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :deleted_at, :datetime, if_not_exists: true
    add_index :posts, :deleted_at, if_not_exists: true
  end
end
