namespace :tutorial do
  desc "Set all existing projects and devlogs to tutorial: true"
  task set_all_to_tutorial: :environment do
    puts "Setting all projects to tutorial: true..."
    project_count = Project.update_all(tutorial: true)
    puts "Updated #{project_count} projects"

    puts "Setting all devlogs to tutorial: true..."
    devlog_count = Post::Devlog.update_all(tutorial: true)
    puts "Updated #{devlog_count} devlogs"

    puts "Done! All projects and devlogs are now marked as tutorial."
  end
end
