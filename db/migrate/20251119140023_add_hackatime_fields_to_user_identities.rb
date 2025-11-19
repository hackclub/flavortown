class AddHackatimeFieldsToUserIdentities < ActiveRecord::Migration[8.1]
  def change
    add_column :user_identities, :hackatime_user_id, :string
    add_column :user_identities, :username, :string

    add_index :user_identities, [ :provider, :hackatime_user_id ], unique: true, name: "index_user_identities_on_provider_and_hackatime_user_id"
  end
end


