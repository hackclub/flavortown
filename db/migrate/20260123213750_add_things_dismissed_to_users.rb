class AddThingsDismissedToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :things_dismissed, :string, array: true, default: [], null: false
  end
end
