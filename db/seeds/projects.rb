# db/seeds/projects.rb
# Usage: rails runner db/seeds/projects.rb
#
# Seeds random projects with memberships for development/testing.

PROJECT_TITLES = [
  "Pixel Art Editor",
  "Weather Dashboard",
  "Task Manager Pro",
  "Music Visualizer",
  "Code Snippet Saver",
  "Chat Application",
  "Portfolio Builder",
  "Recipe Finder",
  "Expense Tracker",
  "Markdown Notes",
  "Habit Tracker",
  "Quiz Game",
  "Drawing Canvas",
  "Timer & Pomodoro",
  "File Uploader",
  "URL Shortener",
  "RSS Reader",
  "Voice Recorder",
  "Photo Gallery",
  "Calendar App"
].freeze

PROJECT_DESCRIPTIONS = [
  "A simple and intuitive tool built during a weekend hackathon.",
  "My first project using Rails and Hotwire. Still learning!",
  "Built this to solve a problem I had every day.",
  "Inspired by a tutorial, but added my own twist.",
  "A collaborative project with friends from Hack Club.",
  "Started as a school project, now it's something I'm proud of.",
  "Experimenting with new technologies and having fun.",
  "A minimalist approach to a common problem.",
  "Built with accessibility in mind from day one.",
  "My attempt at recreating a popular app from scratch."
].freeze

PROJECT_TYPES = [ nil, "web", "mobile", "desktop", "cli", "game", "hardware" ].freeze

SHIP_STATUSES = %w[draft submitted under_review approved rejected].freeze

FIRST_NAMES = %w[Alex Jordan Taylor Morgan Casey Riley Quinn Avery Charlie Sam Drew Jamie Parker Sage River].freeze
LAST_NAMES = %w[Smith Johnson Williams Brown Jones Garcia Miller Davis Rodriguez Martinez Anderson Thomas Jackson White Harris].freeze

puts "Seeding random users and projects..."

user_count = ENV.fetch("USER_COUNT", 15).to_i

users = user_count.times.map do |i|
  first = FIRST_NAMES.sample
  last = LAST_NAMES.sample
  slack_id = "U_SEED_#{SecureRandom.hex(6).upcase}"

  User.find_or_create_by!(slack_id: slack_id) do |u|
    u.email = "#{first.downcase}.#{last.downcase}.#{SecureRandom.hex(3)}@example.com"
    u.first_name = first
    u.last_name = last
    u.display_name = "#{first} #{last}"
  end
end

puts "Created #{users.size} users."

count = ENV.fetch("PROJECT_COUNT", 10).to_i

count.times do |i|
  title = "#{PROJECT_TITLES.sample} #{SecureRandom.hex(3)}"

  project = Project.create!(
    title: title,
    description: PROJECT_DESCRIPTIONS.sample,
    project_type: PROJECT_TYPES.sample,
    demo_url: [ nil, "https://example.com/demo/#{SecureRandom.hex(4)}" ].sample,
    repo_url: [ nil, "https://github.com/hackclub/#{title.parameterize}" ].sample,
    readme_url: [ nil, "https://github.com/hackclub/#{title.parameterize}/blob/main/README.md" ].sample,
    ship_status: SHIP_STATUSES.sample,
    shipped_at: [ nil, rand(1..30).days.ago ].sample
  )

  owner = users.sample
  Project::Membership.create!(
    project: project,
    user: owner,
    role: :owner
  )

  if rand < 0.3 && users.size > 1
    contributor = (users - [ owner ]).sample
    Project::Membership.create!(
      project: project,
      user: contributor,
      role: :contributor
    )
  end

  puts "Created project: #{project.title} (id=#{project.id})"
end

puts "Done seeding #{count} projects."
