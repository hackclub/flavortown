class RemoveHackatimeIndexFromUserIdentities < ActiveRecord::Migration[8.1]
  def change
    remove_index :user_identities, name: "index_user_identities_on_provider_and_hackatime_user_id"
  end
end
