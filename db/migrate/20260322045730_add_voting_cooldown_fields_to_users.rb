class AddVotingCooldownFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :voting_cooldown_until, :datetime
    add_column :users, :voting_cooldown_stage, :integer, null: false, default: 0
    add_column :users, :voting_lock_count, :integer, null: false, default: 0
    add_column :users, :last_clean_vote_at, :datetime
  end
end
