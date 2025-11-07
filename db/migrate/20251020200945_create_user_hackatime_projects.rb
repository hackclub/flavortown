class CreateUserHackatimeProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :user_hackatime_projects do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: true, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :user_hackatime_projects, [ :user_id, :name ], unique: true
  end
end
