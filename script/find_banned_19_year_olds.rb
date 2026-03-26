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
require "csv"

execute = ARGV.include?("--execute")
cutoff_date = Date.new(2025, 12, 15)
candidate_rows = []
updated_count = 0

User.where(verification_status: "verified").find_each do |user|
  next if user.ysws_eligible?
  next if user.manual_ysws_override == false
  next if user.birthday.nil?

  turned_19_on = user.birthday.advance(years: 19)
  next unless turned_19_on > cutoff_date

  candidate_rows << [ user.id, user.email, turned_19_on.iso8601, user.created_at&.iso8601 ]

  if execute && !user.banned? && user.manual_ysws_override != true
    puts "user #{user.id} with email #{user.email} is to be unbanned"
    PaperTrail.request(whodunnit: "script/find_banned_19_year_olds.rb") do
      user.update!(manual_ysws_override: true)
      puts "user #{user.id} with email #{user.email} overriden"
      updated_count += 1
    end
  end
end

puts "#{candidate_rows.size} users found"
puts "#{updated_count} users changed" if execute

puts CSV.generate_line([ "id", "email", "turned_19_on", "created_at" ])
candidate_rows.each { |row| puts CSV.generate_line(row) }
