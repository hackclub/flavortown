class AddUuidToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :uuid, :uuid, default: "gen_random_uuid()", null: false
    add_index :users, :uuid, unique: true
  end
end
