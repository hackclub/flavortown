class CreateProjectSkips < ActiveRecord::Migration[8.1]
  def change
    create_table :project_skips do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end

    add_index :project_skips, [ :user_id, :project_id ], unique: true
  end
end
