class AddVotingLockedToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :voting_locked, :boolean, null: false, default: false
  end
end
