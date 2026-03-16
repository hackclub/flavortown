class CreateUserProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :user_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.text :bio
      t.text :custom_css

      t.timestamps
    end
  end
end
