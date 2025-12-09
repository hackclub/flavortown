class AddHcbemailToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :hcb_email, :string
  end
end
