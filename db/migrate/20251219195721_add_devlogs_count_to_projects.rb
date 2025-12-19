class AddDevlogsCountToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :devlogs_count, :integer, default: 0, null: false

    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE projects
          SET devlogs_count = (
            SELECT COUNT(*)
            FROM posts
            WHERE posts.project_id = projects.id
              AND posts.postable_type = 'Post::Devlog'
          )
        SQL
      end
    end
  end
end
