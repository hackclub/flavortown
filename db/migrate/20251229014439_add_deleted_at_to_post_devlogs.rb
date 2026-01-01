class AddDeletedAtToPostDevlogs < ActiveRecord::Migration[8.1]
  def change
    add_column :post_devlogs, :deleted_at, :datetime
    add_index :post_devlogs, :deleted_at
  end
end
