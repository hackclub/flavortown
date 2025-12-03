class AddIndexesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_index :users, :email
    add_index :users, :slack_id, unique: true
  end
end
