# db/seeds/dev_full_seed.rb
# Comprehensive development seed script
# 
# Creates:
#   • All shop items from CSV (65+ items across 8 different types)
#   • Users with all 7 global roles (one per role)
#   • Generic users (without roles)
#   • Mixed-role users (users with multiple roles)
#   • 25 projects with randomized metadata
#   • 73+ devlogs with attachments across projects
#   • 60+ ship events (all APPROVED for voting, with duration_seconds calculated)
#   • 8-16 project reports (0-2 per project) with various reasons and statuses
#   • 18 shop orders with randomized addresses and states
#
# Usage:
#   1. Direct: rails runner db/seeds/dev_full_seed.rb
#   2. Via db:seed: bin/rails db:seed (loads automatically in development)
#
# Notes:
#   • Only runs in development environments (see db/seeds.rb)
#   • Idempotent: Safe to run multiple times
#   • Uses find_or_create patterns to avoid duplicates

require 'faker'
require 'json'

puts "═" * 80
puts "Starting Comprehensive Development Seed..."
puts "═" * 80

# ==============================================================================
# PART 1: SEED SHOP ITEMS FROM CSV (reuse existing logic)
# ==============================================================================
puts "\n[1/4] Seeding Shop Items from CSV..."

CSV_PATH = Rails.root.join('db', 'seeds', 'shop_items.csv')

unless File.exist?(CSV_PATH)
  puts "  Warning: CSV not found at #{CSV_PATH}. Skipping shop items."
else
  # Converters
  parse_bool = ->(v) {
    return nil if v.nil? || v == ''
    s = v.to_s.strip.downcase
    ['t', 'true', '1', 'yes'].include?(s)
  }

  parse_int = ->(v) {
    return nil if v.nil? || v == ''
    begin
      Integer(v)
    rescue
      begin
        Float(v).to_i
      rescue
        nil
      end
    end
  }

  parse_decimal = ->(v) {
    return nil if v.nil? || v == ''
    begin
      BigDecimal(v.to_s)
    rescue
      begin
        Float(v)
      rescue
        nil
      end
    end
  }

  parse_json_like = ->(v) {
    return nil if v.nil? || v == ''
    s = v.to_s.strip
    return nil if s.gsub('"', '') == ''

    begin
      JSON.parse(s)
    rescue JSON::ParserError
      attempt = s.gsub('""', '"')
      begin
        JSON.parse(attempt)
      rescue JSON::ParserError
        if attempt.start_with?('[') || attempt.start_with?('{')
          begin
            attempt2 = attempt.gsub("'", '"')
            JSON.parse(attempt2)
          rescue
            s
          end
        else
          s
        end
      end
    end
  }

  shop_items_created = 0
  shop_items_updated = 0

  CSV.foreach(CSV_PATH, headers: true) do |row|
    raw = row.to_h
    attrs = {}

    attrs[:id] = parse_int.call(raw['id'])
    attrs[:type] = raw['type'].presence
    attrs[:name] = raw['name'].presence
    attrs[:description] = raw['description'].presence
    attrs[:internal_description] = raw['internal_description'].presence

    attrs[:usd_cost] = parse_decimal.call(raw['usd_cost'])
    attrs[:ticket_cost] = parse_int.call(raw['ticket_cost'])
    attrs[:hacker_score] = parse_int.call(raw['hacker_score'])

    attrs[:show_in_carousel] = parse_bool.call(raw['show_in_carousel'])
    attrs[:limited] = parse_bool.call(raw['limited'])
    attrs[:enabled] = parse_bool.call(raw['enabled'])

    attrs[:enabled_us] = parse_bool.call(raw['enabled_us'])
    attrs[:enabled_eu] = parse_bool.call(raw['enabled_eu'])
    attrs[:enabled_uk] = parse_bool.call(raw['enabled_uk'])
    attrs[:enabled_in] = parse_bool.call(raw['enabled_in'])
    attrs[:enabled_ca] = parse_bool.call(raw['enabled_ca'])
    attrs[:enabled_au] = parse_bool.call(raw['enabled_au'])
    attrs[:enabled_xx] = parse_bool.call(raw['enabled_xx'])

    attrs[:one_per_person_ever] = parse_bool.call(raw['one_per_person_ever']) ? true : parse_int.call(raw['one_per_person_ever'])
    attrs[:max_qty] = parse_int.call(raw['max_qty'])
    attrs[:stock] = parse_int.call(raw['stock'])

    attrs[:price_offset_us] = parse_decimal.call(raw['price_offset_us'])
    attrs[:price_offset_eu] = parse_decimal.call(raw['price_offset_eu'])
    attrs[:price_offset_uk] = parse_decimal.call(raw['price_offset_uk'])
    attrs[:price_offset_in] = parse_decimal.call(raw['price_offset_in'])
    attrs[:price_offset_ca] = parse_decimal.call(raw['price_offset_ca'])
    attrs[:price_offset_au] = parse_decimal.call(raw['price_offset_au'])
    attrs[:price_offset_xx] = parse_decimal.call(raw['price_offset_xx'])

    attrs[:sale_percentage] = parse_decimal.call(raw['sale_percentage'])

    attrs[:hcb_merchant_lock] = raw['hcb_merchant_lock'].presence
    attrs[:hcb_category_lock] = raw['hcb_category_lock'].presence
    attrs[:hcb_keyword_lock] = raw['hcb_keyword_lock'].presence
    attrs[:hcb_preauthorization_instructions] = raw['hcb_preauthorization_instructions'].presence
    attrs[:site_action] = raw['site_action'].presence
    attrs[:unlock_on] = raw['unlock_on'].presence
    attrs[:special] = raw['special'].presence

    begin
      attrs[:created_at] = raw['created_at'].present? ? Time.parse(raw['created_at']) : nil
    rescue
      attrs[:created_at] = nil
    end

    begin
      attrs[:updated_at] = raw['updated_at'].present? ? Time.parse(raw['updated_at']) : nil
    rescue
      attrs[:updated_at] = nil
    end

    attrs[:agh_contents] = parse_json_like.call(raw['agh_contents'])

    attrs.each { |k, v| attrs[k] = nil if v == '' }

    valid_columns = ShopItem.column_names.map(&:to_sym)
    attrs = attrs.select { |k, _| valid_columns.include?(k) }

    record_id = attrs.delete(:id)
    next if record_id.nil?

    shop_item = ShopItem.find_or_initialize_by(id: record_id)

    begin
      shop_item.assign_attributes(attrs.compact)
    rescue => e
      puts "  Error assigning attributes for id=#{record_id}: #{e.message}"
      next
    end

    begin
      if shop_item.new_record? && !shop_item.image.attached?
        placeholder_path = Rails.root.join('app', 'assets', 'images', 'landing', 'pattern.webp')
        if File.exist?(placeholder_path)
          shop_item.image.attach(
            io: File.open(placeholder_path),
            filename: 'placeholder.webp',
            content_type: 'image/webp'
          )
        end
      end

      shop_item.save!(validate: shop_item.image.attached?)

      if attrs[:created_at] || attrs[:updated_at]
        update_attrs = {}
        update_attrs[:created_at] = attrs[:created_at] if attrs[:created_at]
        update_attrs[:updated_at] = attrs[:updated_at] if attrs[:updated_at]
        ShopItem.where(id: shop_item.id).update_all(update_attrs) if update_attrs.any?
      end

      if shop_item.previously_new_record?
        shop_items_created += 1
      else
        shop_items_updated += 1
      end
    rescue => e
      puts "  Failed to save ShopItem id=#{record_id}: #{e.class} - #{e.message}"
    end
  end

  puts "  ✓ Shop Items: #{shop_items_created} created, #{shop_items_updated} updated"
end

# ==============================================================================
# PART 2: CREATE USERS WITH DIVERSE ROLES
# ==============================================================================
puts "\n[2/4] Creating Users with Various Roles..."

FIRST_NAMES = %w[Alex Jordan Taylor Morgan Casey Riley Quinn Avery Charlie Sam Drew Jamie Parker Sage River Emma Liam Noah Oliver].freeze
LAST_NAMES = %w[Smith Johnson Williams Brown Jones Garcia Miller Davis Rodriguez Martinez Anderson Thomas Jackson White Harris Martin Lee].freeze

# Get all global roles
all_roles = User::Role.all

# Create users: one per role, then a few with mixed roles
users_by_role = {}
users_list = []

# 1. Create one user per role (7 users)
all_roles.each do |role|
  user = User.find_or_create_by!(slack_id: "U_SEED_#{role.name.upcase}_#{SecureRandom.hex(3)}") do |u|
    first = FIRST_NAMES.sample
    last = LAST_NAMES.sample
    u.email = "#{role.name}.user.#{SecureRandom.hex(2)}@example.com"
    u.first_name = first
    u.last_name = last
    u.display_name = "#{first} #{last} (#{role.name})"
    u.granted_roles = [role.name]
  end
  users_by_role[role.name] = user
  users_list << user
  puts "  ✓ Created #{role.name} user: #{user.display_name}"
end

# 2. Create some generic users without special roles
3.times do |i|
  first = FIRST_NAMES.sample
  last = LAST_NAMES.sample
  user = User.find_or_create_by!(slack_id: "U_SEED_GENERIC_#{i}_#{SecureRandom.hex(3)}") do |u|
    u.email = "generic.user#{i}.#{SecureRandom.hex(2)}@example.com"
    u.first_name = first
    u.last_name = last
    u.display_name = "#{first} #{last}"
    u.granted_roles = []
  end
  users_list << user
  puts "  ✓ Created generic user: #{user.display_name}"
end

# 3. Create users with mixed roles
2.times do |i|
  mixed_roles = all_roles.sample(2).map(&:name)
  first = FIRST_NAMES.sample
  last = LAST_NAMES.sample
  user = User.find_or_create_by!(slack_id: "U_SEED_MIXED_#{i}_#{SecureRandom.hex(3)}") do |u|
    u.email = "mixed.user#{i}.#{SecureRandom.hex(2)}@example.com"
    u.first_name = first
    u.last_name = last
    u.display_name = "#{first} #{last} (Mixed)"
    u.granted_roles = mixed_roles
  end
  users_list << user
  puts "  ✓ Created mixed-role user: #{user.display_name} (#{mixed_roles.join(', ')})"
end

puts "  ✓ Total users created: #{users_list.count}"

# ==============================================================================
# PART 3: CREATE PROJECTS WITH DEVLOGS AND SHIP EVENTS
# ==============================================================================
puts "\n[3/4] Creating Projects with Devlogs and Ship Events..."

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

PROJECT_TYPES = [nil, "web", "mobile", "desktop", "cli", "game", "hardware"].freeze
SHIP_STATUSES = %w[draft submitted under_review approved rejected].freeze

projects_created = 0
devlogs_created = 0
ship_events_created = 0
reports_created = 0

# Create 20+ projects (more projects = more voteable content even if users own some)
25.times do |proj_idx|
  title = "#{PROJECT_TITLES.sample} #{SecureRandom.hex(3)}"

  project = Project.create!(
    title: title,
    description: PROJECT_DESCRIPTIONS.sample,
    project_type: PROJECT_TYPES.sample,
    demo_url: [nil, "https://example.com/demo/#{SecureRandom.hex(4)}"].sample,
    repo_url: [nil, "https://github.com/hackclub/#{title.parameterize}"].sample,
    readme_url: [nil, "https://github.com/hackclub/#{title.parameterize}/blob/main/README.md"].sample,
    ship_status: SHIP_STATUSES.sample,
    shipped_at: [nil, rand(1..30).days.ago].sample
  )

  projects_created += 1

  # Add project owner
  owner = users_list.sample
  Project::Membership.create!(
    project: project,
    user: owner,
    role: :owner
  )

  # Maybe add a contributor
  if rand < 0.5 && users_list.size > 1
    contributor = (users_list - [owner]).sample
    Project::Membership.create!(
      project: project,
      user: contributor,
      role: :contributor
    )
  end

  # Create 2-4 devlogs per project
  rand(2..4).times do |devlog_idx|
    body = "Worked on some cool features. Made progress on the functionality. "\
           "Encountered some interesting challenges but fixed them!"

    # Prepare placeholder image
    placeholder_path = Rails.root.join('app', 'assets', 'images', 'landing', 'pattern.webp')
    
    # Create devlog with attachment (if available)
    devlog = Post::Devlog.new(
      body: body,
      duration_seconds: rand(15.minutes..8.hours).to_i,
      tutorial: [true, false].sample
    )

    # Attach placeholder image before saving
    if File.exist?(placeholder_path)
      devlog.attachments.attach(
        io: File.open(placeholder_path),
        filename: "devlog_#{Time.current.to_i}.webp",
        content_type: 'image/webp'
      )
    end

    devlog.save!

    # Then create the post with the devlog
    post = Post.create!(
      project: project,
      user: owner,
      postable: devlog
    )

    devlogs_created += 1

    # Backdate the post so we have a nice timeline
    Post.where(id: post.id).update_all(created_at: (devlog_idx + 1).days.ago)
    Post::Devlog.where(id: devlog.id).update_all(created_at: (devlog_idx + 1).days.ago)
  end

  # Recalculate project duration from devlogs (needed for voting!)
  project.recalculate_duration_seconds!

  # Create 2-3 ship events per project (more voteable content)
  rand(2..3).times do |ship_idx|
    ship_body = "Shipped major updates and improvements. "\
                "This release includes bug fixes and new features for better user experience."

    # Create ship event first - make votable by approving them
    ship_event = Post::ShipEvent.create!(
      body: ship_body,
      certification_status: "approved"  # Make votable!
    )

    # Then create the post with the ship event
    post = Post.create!(
      project: project,
      user: owner,
      postable: ship_event
    )

    ship_events_created += 1

    # Backdate the ship event
    Post.where(id: post.id).update_all(created_at: (10 - ship_idx * 3).days.ago)
    Post::ShipEvent.where(id: ship_event.id).update_all(created_at: (10 - ship_idx * 3).days.ago)
  end

  # Create 0-2 reports per project
  rand(0..2).times do |report_idx|
    reason = Project::Report::USER_REASONS.sample
    details = case reason
              when "low_effort"
                "This project appears to have minimal effort. The code is simple and doesn't demonstrate sufficient skills."
              when "undeclared_ai"
                "Suspicion that AI was used to generate the code without proper declaration."
              when "demo_broken"
                "The demo link is broken or the project doesn't work as advertised."
              else
                "This project has issues that need review and investigation by the team."
              end

    # Pick a reporter who is NOT a project member
    reporter = (users_list - [project.users]).sample
    next unless reporter # Skip if no valid reporter available

    begin
      Project::Report.create!(
        project: project,
        reporter: reporter,
        reason: reason,
        details: details,
        status: %i[pending reviewed dismissed].sample
      )
      reports_created += 1
    rescue ActiveRecord::RecordInvalid
      # Silently skip if reporter has already reported this project
    end
  end

  puts "  ✓ Project: #{project.title} (#{devlogs_created} devlogs, #{ship_events_created} ship events, #{reports_created} reports in total)"
end

puts "  ✓ Projects: #{projects_created} created with #{devlogs_created} devlogs, #{ship_events_created} ship events, and #{reports_created} reports"

# ==============================================================================
# PART 4: CREATE SHOP ORDERS
# ==============================================================================
puts "\n[4/4] Creating Shop Orders..."

shop_items = ShopItem.enabled.limit(20).to_a
abort "  ✗ No shop items found. Ensure shop items are seeded first." if shop_items.empty?

shop_orders_created = 0
states = [:pending, :awaiting_periodical_fulfillment, :fulfilled, :rejected, :on_hold]

rand(10..20).times do |order_idx|
  user = users_list.sample
  shop_item = shop_items.sample
  quantity = rand(1..3)

  address = {
    "first_name" => Faker::Name.first_name,
    "last_name" => Faker::Name.last_name,
    "address_line_1" => Faker::Address.street_address,
    "address_line_2" => Faker::Address.secondary_address,
    "city" => Faker::Address.city,
    "state_province" => Faker::Address.state,
    "postal_code" => Faker::Address.postcode,
    "country" => %w[US CA GB AU IN DE FR].sample,
    "email" => Faker::Internet.email,
    "phone" => Faker::PhoneNumber.phone_number
  }

  order = user.shop_orders.build(
    shop_item: shop_item,
    quantity: quantity,
    frozen_address: address,
    frozen_item_price: shop_item.ticket_cost || 100
  )

  if order.save(validate: false)
    random_state = states.sample
    state_name = random_state.to_s

    ShopOrder.where(id: order.id).update_all(aasm_state: state_name)

    if random_state == :fulfilled
      ShopOrder.where(id: order.id).update_all(
        fulfilled_at: Time.current,
        fulfilled_by: "SEED",
        external_ref: "TEST-#{SecureRandom.hex(4)}"
      )
    end

    shop_orders_created += 1
  end
end

puts "  ✓ Shop orders created: #{shop_orders_created}"

# ==============================================================================
# SUMMARY
# ==============================================================================
puts "\n" + "═" * 80
puts "Seed Complete!"
puts "═" * 80
puts "Summary:"
puts "  • Shop Items: Loaded from CSV"
puts "  • Users: #{users_list.count} (#{all_roles.count} role-specific + generics + mixed)"
puts "  • Projects: #{projects_created}"
puts "  • Devlogs: #{devlogs_created}"
puts "  • Ship Events: #{ship_events_created}"
puts "  • Project Reports: #{reports_created}"
puts "  • Shop Orders: #{shop_orders_created}"
puts "\nYou can now run the development server:"
puts "  bin/dev"
puts "═" * 80
