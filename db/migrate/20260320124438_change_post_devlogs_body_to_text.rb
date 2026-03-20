class ChangePostDevlogsBodyToText < ActiveRecord::Migration[8.1]
  def up
    change_column :post_devlogs, :body, :text
  end

  def down
    change_column :post_devlogs, :body, :string, limit: 255
  end
end
