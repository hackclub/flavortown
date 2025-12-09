class AddApiKeyToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :api_key, :string
  end
end
