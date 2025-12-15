class RemoveSessionTokenFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_index :users, :session_token, if_exists: true
    remove_column :users, :session_token, :string
  end
end
