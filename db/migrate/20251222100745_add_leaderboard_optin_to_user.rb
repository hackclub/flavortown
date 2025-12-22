class AddLeaderboardOptinToUser < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :leaderboard_optin, :boolean, default: false, null: false
  end
end
