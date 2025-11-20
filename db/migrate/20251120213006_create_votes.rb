class CreateVotes < ActiveRecord::Migration[8.1]
  def change
    create_table :votes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true
      t.integer :score, null: false
      t.integer :category, null: false, default: 0

      t.timestamps
    end

    add_index :votes, [ :user_id, :project_id, :category ], unique: true
  end
end
