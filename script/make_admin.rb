#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage:
#   script/make_admin.rb --email person@example.com
#   bin/rails runner script/make_admin.rb --email person@example.com
#
# This script only runs in development/test.

require_relative "../config/environment" unless defined?(Rails)

def usage
  puts "Usage: script/make_admin.rb --email EMAIL"
  puts "Examples:"
  puts "  script/make_admin.rb --email person@example.com"
  puts "  bin/rails runner script/make_admin.rb --email person@example.com"
end

def parse_args(argv)
  args = {}

  while argv.any?
    flag = argv.shift
    case flag
    when "--email"
      args[:email] = argv.shift
    when "--help", "-h"
      args[:help] = true
    else
      args[:invalid] = flag
    end
  end

  args
end

args = parse_args(ARGV.dup)

if args[:help]
  usage
  exit 0
end

if args[:invalid]
  puts "Unknown option: #{args[:invalid]}"
  usage
  exit 1
end

if args[:email].to_s.strip.empty?
  puts "Missing required option: --email"
  usage
  exit 1
end

if !Rails.env.development? && !Rails.env.test?
  puts "Refusing to run in #{Rails.env}"
  exit 1
end

email = args[:email].to_s.strip.downcase

user = User.where("LOWER(email) = ?", email).first

unless user
  puts "User not found (email=#{email})"
  exit 1
end

if user.admin?
  puts "User #{user.id} (#{user.email}) is already admin"
  exit 0
end

user.make_admin!
puts "Granted admin role to user #{user.id} (#{user.email})"
