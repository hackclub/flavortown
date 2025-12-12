class CreateUserAchievements < ActiveRecord::Migration[8.1]
  def change
    create_table :user_achievements do |t|
      t.references :user, null: false, foreign_key: true
      t.string :achievement_slug, null: false
      t.datetime :earned_at, null: false

      t.timestamps
    end

    add_index :user_achievements, [ :user_id, :achievement_slug ], unique: true
  end
end
