class AddMoreHCBCredentails < ActiveRecord::Migration[8.1]
  def change
    add_column :hcb_credentials, :client_id, :string
    add_column :hcb_credentials, :client_secret, :string
    add_column :hcb_credentials, :redirect_uri, :string
    add_column :hcb_credentials, :base_url, :string
  end
end
