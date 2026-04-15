class AddMarkedSusByToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :marked_sus_by, :string, array: true, default: [], null: false
  end
end
