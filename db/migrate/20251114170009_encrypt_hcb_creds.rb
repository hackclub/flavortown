class EncryptHCBCreds < ActiveRecord::Migration[8.1]
  def change
    remove_column :hcb_credentials, :client_secret, :string
    remove_column :hcb_credentials, :access_token, :string
    remove_column :hcb_credentials, :refresh_token, :string

    add_column :hcb_credentials, :client_secret_ciphertext, :text
    add_column :hcb_credentials, :access_token_ciphertext, :text
    add_column :hcb_credentials, :refresh_token_ciphertext, :text
  end
end
