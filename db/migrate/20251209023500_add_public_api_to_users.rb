class AddPublicApiToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :public_api, :boolean
  end
end
