# db/seeds/funnel_events.rb
# Seed script to create fake funnel events for dashboard visualization
#
# Creates a realistic funnel dataset:
#   • Drop-offs at each step reflecting real user behavior
#   • Realistic percentages matching typical conversion funnels

puts "\n" + "═" * 80
puts "Seeding Funnel Events..."
puts "═" * 80

# Only seed in development/test
unless Rails.env.development? || Rails.env.test?
  puts "Skipping funnel events seed (not development/test)"
  return
end

# Clear existing funnel events
existing_count = FunnelEvent.count
if existing_count > 0
  puts "Clearing #{existing_count} existing funnel events..."
  FunnelEvent.delete_all
end

# Define the funnel steps and target event counts
FUNNEL_STEPS = {
  "start_flow_started" => 1_000,
  "start_flow_name" => 933,
  "start_flow_project" => 926,
  "start_flow_devlog" => 828,
  "start_flow_signin" => 462,
  "identity_verified" => 286,
  "hackatime_linked" => 290,
  "project_created" => 173,
  "devlog_created" => 128
}.freeze

INITIAL_USER_COUNT = FUNNEL_STEPS.values.first

puts "\nGenerating funnel event data for #{INITIAL_USER_COUNT} initial users...\n"

total_created = 0
user_id = 0

# Simulate the funnel flow using the target counts above
FUNNEL_STEPS.each do |step_name, users_at_this_step|
  puts "  • #{step_name}: generating #{users_at_this_step} events..."

  users_at_this_step.times do
    created_at = 30.days.ago + rand(30.days).seconds
    FunnelEvent.create!(
      event_name: step_name,
      email: "user_#{user_id}@example.com",
      properties: { user_id: user_id },
      created_at: created_at
    )
    user_id += 1
  end

  total_created += users_at_this_step
  puts "    ✓ #{users_at_this_step} events created"
end

puts "\n" + "═" * 80
puts "Funnel Events Summary:"
puts "═" * 80

total = FunnelEvent.count
puts "Total events created: #{total}"
puts

# Show summary by step
first_step_count = FunnelEvent.by_event(FUNNEL_STEPS.keys.first).count
FUNNEL_STEPS.each do |step_name, _|
  count = FunnelEvent.by_event(step_name).count
  pct =
    if first_step_count > 0
      (count.to_f / first_step_count * 100).round(2)
    else
      0
    end
  puts "  #{step_name.ljust(25)} #{count.to_s.rjust(10)} (#{pct}%)"
end

puts "═" * 80
puts "\n✅ Funnel events seeded successfully!"
puts
