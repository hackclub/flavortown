class AddCipherTextToUserIdentities < ActiveRecord::Migration[8.0]
  def change
    add_column :user_identities, :access_token_ciphertext, :text
    add_column :user_identities, :refresh_token_ciphertext, :text
    # blind_index: we're using it for querying encrypted cols
    add_column :user_identities, :access_token_bidx, :string
    add_column :user_identities, :refresh_token_bidx, :string

    add_index :user_identities, :access_token_bidx
    add_index :user_identities, :refresh_token_bidx
  end
end
