# Usage: bin/rails runner script/seed_projects.rb [email]

email = ARGV[0]
user = if email
         User.find_by(email: email)
else
         User.first
end

unless user
  puts "User not found! Please provide your email as an argument."
  puts "Usage: bin/rails runner script/seed_projects.rb your@email.com"
  exit 1
end

puts "Seeding 10 projects for #{user.display_name || user.email}..."

10.times do
  title = Faker::App.name
  # Ensure title is unique-ish if needed, but model doesn't validate uniqueness

  begin
    project = Project.create!(
      title: "#{title} #{SecureRandom.hex(2)}", # Add random suffix to ensure variety
      description: Faker::Company.catch_phrase,
      repo_url: "https://github.com/hackclub/#{title.parameterize}",
      demo_url: "https://#{title.parameterize}.example.com"
    )

    Project::Membership.create!(
      project: project,
      user: user,
      role: :owner
    )

    puts "Created project: #{project.title}"
  rescue ActiveRecord::RecordInvalid => e
    puts "Failed to create project '#{title}': #{e.message}"
  end
end

puts "Done!"
