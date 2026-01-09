class AddDurationSecondsToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :duration_seconds, :integer, default: 0, null: false

    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE projects
          SET duration_seconds = COALESCE((
            SELECT SUM(post_devlogs.duration_seconds)
            FROM posts
            INNER JOIN post_devlogs ON posts.postable_id = post_devlogs.id
            WHERE posts.project_id = projects.id
              AND posts.postable_type = 'Post::Devlog'
          ), 0)
        SQL
      end
    end
  end
end
