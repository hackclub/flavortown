# Seed file to create dummy projects with devlogs
# Run with: bin/rails runner db/seeds/dummy_projects.rb

puts "Creating dummy projects with devlogs..."

# Ensure we have a user to associate with projects
user = User.find_by(email: "demo@hackclub.com") || User.first
unless user
  user = User.create!(
    email: "demo@hackclub.com",
    first_name: "Demo",
    last_name: "User",
    display_name: "DemoHacker",
    slack_id: "UDEMO#{SecureRandom.hex(4).upcase}",
    verification_status: "verified"
  )
end

project_data = [
  {
    title: "Pixel Art Editor",
    description: "A web-based pixel art editor with layers, animations, and export to GIF/PNG. Built with vanilla JS and Canvas API.",
    shipped: true,
    demo_url: "https://pixelart.example.com",
    repo_url: "https://github.com/demohacker/pixel-art-editor"
  },
  {
    title: "CLI Task Manager",
    description: "A terminal-based task manager with vim keybindings, project support, and sync across devices.",
    shipped: false,
    repo_url: "https://github.com/demohacker/cli-tasks"
  },
  {
    title: "Weather Dashboard",
    description: "Real-time weather dashboard with 7-day forecasts, radar maps, and severe weather alerts.",
    shipped: true,
    demo_url: "https://weather.example.com",
    repo_url: "https://github.com/demohacker/weather-dash"
  },
  {
    title: "Multiplayer Snake Game",
    description: "Classic snake game with online multiplayer, leaderboards, and custom skins.",
    shipped: false,
    repo_url: "https://github.com/demohacker/multiplayer-snake"
  },
  {
    title: "Markdown Note App",
    description: "A minimal markdown note-taking app with live preview, tagging, and local-first storage.",
    shipped: true,
    demo_url: "https://notes.example.com",
    repo_url: "https://github.com/demohacker/md-notes"
  },
  {
    title: "Discord Bot for Hackathons",
    description: "A Discord bot to manage hackathon teams, submissions, and judging. Supports multiple events.",
    shipped: false,
    repo_url: "https://github.com/demohacker/hackathon-bot"
  },
  {
    title: "Personal Finance Tracker",
    description: "Track expenses, set budgets, and visualize spending patterns with charts and reports.",
    shipped: true,
    demo_url: "https://finance.example.com",
    repo_url: "https://github.com/demohacker/finance-tracker"
  },
  {
    title: "AI Recipe Generator",
    description: "Generate recipes based on ingredients you have. Uses GPT to suggest creative dishes.",
    shipped: false,
    repo_url: "https://github.com/demohacker/ai-recipes"
  },
  {
    title: "Retro Game Emulator",
    description: "A web-based Game Boy emulator written in Rust and compiled to WebAssembly.",
    shipped: true,
    demo_url: "https://retro.example.com",
    repo_url: "https://github.com/demohacker/retro-emu"
  },
  {
    title: "Study Timer with Pomodoro",
    description: "A study timer app with Pomodoro technique, break reminders, and session statistics.",
    shipped: false,
    repo_url: "https://github.com/demohacker/study-timer"
  }
]

devlog_samples = [
  "Just started this project! Setting up the basic structure and figuring out the architecture.",
  "Made good progress today. Got the core functionality working, though there are still some edge cases to handle.",
  "Hit a tricky bug with async operations. Spent a few hours debugging but finally figured it out!",
  "Added unit tests for the main modules. Code coverage is now at 80%.",
  "Refactored the data layer to use a cleaner pattern. The code is much more maintainable now.",
  "Working on the UI today. Trying to keep it minimal but functional.",
  "Got feedback from friends and fixed several UX issues they pointed out.",
  "Optimized performance by implementing caching. Load times are 3x faster now!",
  "Added dark mode support. Everyone loves dark mode these days.",
  "Documentation day! Wrote README, added code comments, and created a quick start guide.",
  "Deployed to production for the first time. Exciting to see it live!",
  "Fixed a critical bug reported by users. Note to self: always validate input.",
  "Added new feature based on user requests. The community feedback has been great.",
  "Spent time cleaning up technical debt. Not glamorous but necessary.",
  "Reached a major milestone today. The MVP is complete!"
]

project_data.each do |data|
  project = Project.find_or_create_by!(title: data[:title]) do |p|
    p.description = data[:description]
    p.demo_url = data[:demo_url]
    p.repo_url = data[:repo_url]
  end

  # Ensure the user is a member of the project
  Project::Membership.find_or_create_by!(project: project, user: user) do |m|
    m.role = :owner
  end

  # Create devlogs for the project (3-5 per project)
  devlog_count = rand(3..5)
  devlog_count.times do |i|
    devlog = Post::Devlog.create!(body: devlog_samples.sample)

    Post.find_or_create_by!(
      project: project,
      user: user,
      postable: devlog
    )
  end

  # If shipped, create a ShipEvent
  if data[:shipped]
    hours = rand(10..100).to_f + rand.round(1)
    ship_event = Post::ShipEvent.create!(
      body: "Shipped #{data[:title]}! 🚀",
      hours: hours,
      multiplier: 1.0,
      payout: hours * 10
    )

    Post.create!(
      project: project,
      user: user,
      postable: ship_event
    )

    puts "  ✓ Created SHIPPED project: #{data[:title]} (#{devlog_count} devlogs)"
  else
    puts "  ○ Created project: #{data[:title]} (#{devlog_count} devlogs)"
  end
end

puts "\nDone! Created #{project_data.count} projects (#{project_data.count { |p| p[:shipped] }} shipped, #{project_data.count { |p| !p[:shipped] }} unshipped)"
puts "Total devlogs created: #{Post::Devlog.count}"
