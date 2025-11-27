class CreateHCBCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :hcb_credentials do |t|
      t.string :refresh_token
      t.string :access_token

      t.timestamps
    end
  end
end
