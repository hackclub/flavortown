class AddTestColumnToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :test_column, :string
  end
end
