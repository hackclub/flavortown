class AddSettingsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :send_votes_to_slack, :boolean, default: false, null: false
    add_column :users, :vote_anonymously, :boolean, default: false, null: false
  end
end
