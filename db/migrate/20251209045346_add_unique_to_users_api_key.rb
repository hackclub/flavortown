class AddUniqueToUsersApiKey < ActiveRecord::Migration[8.1]
  def change
    add_index :users, :api_key, unique: true
  end
end
