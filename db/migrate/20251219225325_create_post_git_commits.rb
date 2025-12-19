class CreatePostGitCommits < ActiveRecord::Migration[8.1]
  def change
    create_table :post_git_commits do |t|
      t.string :sha, null: false
      t.text :message
      t.string :author_name
      t.string :author_email
      t.datetime :authored_at
      t.string :url
      t.integer :additions, default: 0
      t.integer :deletions, default: 0
      t.integer :files_changed, default: 0

      t.timestamps
    end

    add_index :post_git_commits, :sha, unique: true
  end
end
