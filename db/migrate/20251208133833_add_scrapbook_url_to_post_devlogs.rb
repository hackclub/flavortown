class AddScrapbookUrlToPostDevlogs < ActiveRecord::Migration[8.1]
  def change
    add_column :post_devlogs, :scrapbook_url, :string
  end
end
