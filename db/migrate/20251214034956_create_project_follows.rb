class CreateProjectFollows < ActiveRecord::Migration[8.1]
  def change
    create_table :project_follows do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end

    add_index :project_follows, [ :user_id, :project_id ], unique: true
  end
end
