class RemoveUsernameAndHackatimeUserIdFromUserIdentities < ActiveRecord::Migration[8.1]
  def change
    remove_column :user_identities, :username, :string
    remove_column :user_identities, :hackatime_user_id, :string
  end
end
