class AddIndexToUsersApiKey < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :users, :api_key, unique: true, algorithm: :concurrently
  end
end
