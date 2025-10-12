class CreateUserIdentities < ActiveRecord::Migration[8.0]
  def change
    create_table :user_identities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider
      t.string :uid
      t.string :access_token
      t.string :refresh_token

      t.timestamps
    end
  end
end
