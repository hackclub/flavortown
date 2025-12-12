# Seeds for Ship Certification testing
# Run with: bin/rails runner db/seeds/ship_certifications.rb

puts "🚀 Seeding Ship Certification test data..."

# Create test users if they don't exist
test_users = []
5.times do |i|
  user = User.find_or_create_by!(email: "testuser#{i + 1}@example.com") do |u|
    u.display_name = "Test User #{i + 1}"
    u.slack_id = "U#{SecureRandom.hex(5).upcase}"
  end
  test_users << user
end

# Create a reviewer user
reviewer = User.find_or_create_by!(email: "reviewer@example.com") do |u|
  u.display_name = "Test Reviewer"
  u.slack_id = "U#{SecureRandom.hex(5).upcase}"
end
reviewer.role_assignments.find_or_create_by!(role: :admin)

puts "✅ Created #{test_users.count} test users and 1 reviewer"

# Project types for variety
project_types = %w[web mobile game hardware cli other]

# Create projects with various ship statuses
projects_data = [
  # Submitted projects (awaiting review)
  { title: "Weather Dashboard", status: :submitted, type: "web", hours: 12 },
  { title: "Task Manager CLI", status: :submitted, type: "cli", hours: 8 },
  { title: "Pokemon Clone", status: :submitted, type: "game", hours: 25 },
  { title: "Fitness Tracker", status: :submitted, type: "mobile", hours: 15 },
  { title: "LED Matrix Controller", status: :submitted, type: "hardware", hours: 20 },

  # Under review projects
  { title: "Recipe Finder App", status: :under_review, type: "web", hours: 10, reviewer: reviewer },
  { title: "Budget Calculator", status: :under_review, type: "mobile", hours: 6, reviewer: reviewer },

  # Approved projects
  { title: "Portfolio Website", status: :approved, type: "web", hours: 18, reviewer: reviewer },
  { title: "Chess Game", status: :approved, type: "game", hours: 30, reviewer: reviewer },

  # Rejected projects
  { title: "Hello World App", status: :rejected, type: "other", hours: 1, reviewer: reviewer },

  # Draft projects (not yet shipped)
  { title: "Work In Progress", status: :draft, type: "web", hours: 3 }
]

created_projects = []

projects_data.each_with_index do |data, index|
  user = test_users[index % test_users.count]

  project = Project.find_or_initialize_by(title: data[:title])

  if project.new_record?
    project.assign_attributes(
      description: "This is a test project: #{data[:title]}. Built with passion and code.",
      demo_url: "https://example.com/demo/#{data[:title].parameterize}",
      repo_url: "https://github.com/testuser/#{data[:title].parameterize}",
      project_type: data[:type],
      ship_status: data[:status],
      shipped_at: data[:status] != :draft ? rand(1..14).days.ago : nil
    )
    project.save!

    # Create membership
    project.memberships.find_or_create_by!(user: user, role: :owner)

    # Create devlogs with time
    devlog_count = rand(2..5)
    seconds_per_devlog = (data[:hours] * 3600) / devlog_count

    devlog_count.times do |d|
      devlog = Post::Devlog.new(
        body: "Devlog #{d + 1}: Made progress on #{data[:title]}. Things are looking good!",
        duration_seconds: seconds_per_devlog + rand(-1800..1800)
      )
      # Skip attachment validation for seeds
      devlog.define_singleton_method(:at_least_one_attachment) { true }

      post = project.posts.build(
        user: user,
        postable: devlog
      )
      post.save!
    end

    # Create ship event if shipped
    if data[:status] != :draft
      ship_event = Post::ShipEvent.new(
        body: "🚀 Shipped #{data[:title]}! Check it out and let me know what you think.",
        hours: data[:hours].to_f
      )

      post = project.posts.build(
        user: user,
        postable: ship_event
      )
      post.save!
    end

    # Create ship certification record
    if data[:status].in?([:submitted, :under_review, :approved, :rejected])
      cert_state = case data[:status]
                   when :submitted then :pending
                   when :under_review then :pending
                   when :approved then :approved
                   when :rejected then :rejected
                   end

      cert = project.ship_certifications.find_or_create_by!(aasm_state: cert_state) do |c|
        c.reviewer = data[:reviewer]
        c.feedback = case cert_state
                     when :approved then "Great project! Well documented and demo works perfectly."
                     when :rejected then "Project does not meet minimum requirements. Please add more functionality."
                     else nil
                     end
        c.decided_at = cert_state != :pending ? rand(1..7).days.ago : nil
      end
    end

    created_projects << project
    puts "  📦 Created: #{data[:title]} (#{data[:status]})"
  else
    puts "  ⏭️  Skipped: #{data[:title]} (already exists)"
  end
end

puts ""
puts "📊 Summary:"
puts "  - Draft: #{Project.where(ship_status: :draft).count}"
puts "  - Submitted: #{Project.where(ship_status: :submitted).count}"
puts "  - Under Review: #{Project.where(ship_status: :under_review).count}"
puts "  - Approved: #{Project.where(ship_status: :approved).count}"
puts "  - Rejected: #{Project.where(ship_status: :rejected).count}"
puts ""
puts "✅ Ship Certification seed complete!"
