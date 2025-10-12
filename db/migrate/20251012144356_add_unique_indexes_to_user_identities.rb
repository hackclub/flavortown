class AddUniqueIndexesToUserIdentities < ActiveRecord::Migration[8.0]
  def change
    add_index :user_identities, [ :user_id, :provider ], unique: true
    add_index :user_identities, [ :provider, :uid ], unique: true
  end
end
