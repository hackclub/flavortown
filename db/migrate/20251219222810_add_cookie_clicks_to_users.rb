class AddCookieClicksToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :cookie_clicks, :integer, default: 0, null: false
  end
end
