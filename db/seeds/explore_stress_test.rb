# Seed script for testing explore page N+1 fix
# Run with: rails runner db/seeds/explore_stress_test.rb
#
# Creates 1000 projects, each with 10 devlogs, each devlog with 2 image attachments

NUM_PROJECTS = (ENV["NUM_PROJECTS"] || 10).to_i
NUM_DEVLOGS_PER_PROJECT = (ENV["NUM_DEVLOGS"] || 10).to_i
NUM_ATTACHMENTS_PER_DEVLOG = (ENV["NUM_ATTACHMENTS"] || 2).to_i

puts "Creating stress test data for explore page..."
puts "This will create:"
puts "  - #{NUM_PROJECTS} projects"
puts "  - #{NUM_PROJECTS * NUM_DEVLOGS_PER_PROJECT} devlogs"
puts "  - #{NUM_PROJECTS * NUM_DEVLOGS_PER_PROJECT * NUM_ATTACHMENTS_PER_DEVLOG} attachments"

# Find or create a test user
test_user = User.find_or_create_by!(email: "stress-test@example.com") do |u|
  u.display_name = "Stress Test User"
  u.slack_id = "STRESS_TEST_#{SecureRandom.hex(6)}"
end
puts "Using test user: #{test_user.email}"

# Create a valid placeholder image using ImageMagick directly
placeholder_path = Rails.root.join("test/fixtures/files/placeholder.png")
unless File.exist?(placeholder_path) && File.size(placeholder_path) > 100
  FileUtils.mkdir_p(File.dirname(placeholder_path))
  system("magick -size 100x100 xc:red #{placeholder_path}")
  puts "Created placeholder image at #{placeholder_path}"
end

start_time = Time.now
projects_created = 0

NUM_PROJECTS.times do |i|
  ActiveRecord::Base.transaction do
    project = Project.create!(
      title: "Stress Test Project #{i + 1}",
      description: "A project created for stress testing the explore page performance.",
      tutorial: false
    )

    Project::Membership.create!(
      project: project,
      user: test_user,
      role: "owner"
    )

    NUM_DEVLOGS_PER_PROJECT.times do |j|
      devlog = Post::Devlog.create!(
        body: "Devlog #{j + 1} for project #{i + 1}. This is test content to simulate real devlogs with meaningful text.",
        duration_seconds: rand(900..7200),
        tutorial: false,
        attachments: NUM_ATTACHMENTS_PER_DEVLOG.times.map do |k|
          {
            io: File.open(placeholder_path),
            filename: "attachment_#{j + 1}_#{k + 1}.png",
            content_type: "image/png"
          }
        end
      )

      Post.create!(
        project: project,
        user: test_user,
        postable: devlog,
        created_at: (NUM_DEVLOGS_PER_PROJECT - j).days.ago
      )
    end

    projects_created += 1
    if projects_created % 100 == 0
      elapsed = Time.now - start_time
      rate = projects_created / elapsed
      remaining = (NUM_PROJECTS - projects_created) / rate
      puts "Created #{projects_created}/#{NUM_PROJECTS} projects (#{rate.round(1)}/sec, ~#{remaining.round(0)}s remaining)"
    end
  end
end

elapsed = Time.now - start_time
puts ""
puts "Done! Created #{projects_created} projects in #{elapsed.round(1)} seconds"
puts "Total devlogs: #{Post.of_devlogs.count}"
puts "Total attachments: #{ActiveStorage::Attachment.where(record_type: 'Post::Devlog').count}"
