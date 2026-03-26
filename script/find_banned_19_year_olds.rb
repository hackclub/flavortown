#!/usr/bin/env ruby
# frozen_string_literal: true

# find users that are:
#  a) identity verified
#  b) NOT YSWS eligible (checks both ysws_eligible and manual_ysws_override)
#  c) turned 19 after Dec 15, 2025
#  d) if NOT banned, set manual_ysws_override to true (only with --execute)

# Usage:
#   bin/rails runner script/find_banned_19_year_olds.rb (logs all to-be-unbanned users)
#   bin/rails runner script/find_banned_19_year_olds.rb --execute (unbans users)

require_relative "../config/environment"

cutoff_date = Date.new(2025, 12, 15)
whodunnit = "script/find_banned_19_year_olds.rb"
verified_users = User.where(verification_status: "verified").includes(:identities)

execute = ARGV.include?("--execute")
candidate_rows = []

runner = lambda do
  verified_users.find_each do |user|
    next if user.ysws_eligible?

    birthday = user.birthday
    next if birthday.nil?

    turned_19_on = birthday.advance(years: 19)
    next unless turned_19_on > cutoff_date

    candidate_rows << [
      user.id,
      user.email,
      turned_19_on.iso8601,
      user.created_at&.iso8601
    ]

    next unless execute
    next if user.banned?
    next if user.manual_ysws_override == true

    user.update!(manual_ysws_override: true)

    puts "Overrided User #{user.id} with email: #{user.email}"
  end
end

if execute
  PaperTrail.request(whodunnit: whodunnit) { runner.call }
else
  runner.call
end

if execute
  puts
  puts "Found #{candidate_rows.size} user(s) that are identity-verified, not YSWS-eligible, and turned 19 after #{cutoff_date}"
else
  puts "Found #{candidate_rows.size} user(s) that are identity-verified, not YSWS-eligible, and turned 19 after #{cutoff_date}"
  puts

  puts CSV.generate_line([ "id", "email", "turned_19_on", "created_at" ])
  candidate_rows.each { |row| puts CSV.generate_line(row) }
end
