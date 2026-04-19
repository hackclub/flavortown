class RemoveSkipBalanceFromUsers < ActiveRecord::Migration[8.1]
  def change
    safety_assured { remove_column :users, :skip_balance, :integer }
  end
end
