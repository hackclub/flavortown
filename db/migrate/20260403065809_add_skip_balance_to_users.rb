class AddSkipBalanceToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :skip_balance, :integer, default: 0, null: false
  end
end
