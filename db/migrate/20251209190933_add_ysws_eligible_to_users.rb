class AddYswsEligibleToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :ysws_eligible, :boolean, default: false, null: false
  end
end
