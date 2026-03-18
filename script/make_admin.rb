#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage:
#   bin/rails runner script/make_admin.rb --email person@example.com

def usage
  puts "Usage: bin/rails runner script/make_admin.rb --email EMAIL"
  puts "Examples:"
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

if args[:email].blank?
  puts "Missing required option: --email"
  usage
  exit 1
end

user = User.find_by(email: args[:email])

unless user
  puts "User not found (email=#{args[:email]})"
  exit 1
end

if user.admin?
  puts "User #{user.id} (#{user.email}) is already admin"
  exit 0
end

user.make_admin!
puts "Granted admin role to user #{user.id} (#{user.email})"
