class DropPlaintextTokensFromUserIdentities < ActiveRecord::Migration[8.0]
  def change
    remove_column :user_identities, :access_token, :string
    remove_column :user_identities, :refresh_token, :string
  end
end
