class AddVoteBalanceToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :users, :vote_balance, :integer, default: 0, null: false
  end
end
