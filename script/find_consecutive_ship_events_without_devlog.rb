#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to find consecutive ship events that have no devlog between them
# Usage:
#   rails runner script/find_consecutive_ship_events_without_devlog.rb                    # Check all (dry-run)
#   rails runner script/find_consecutive_ship_events_without_devlog.rb --delete            # Delete dupes (all)
#   rails runner script/find_consecutive_ship_events_without_devlog.rb [project_id]       # Check one project
#   rails runner script/find_consecutive_ship_events_without_devlog.rb [project_id] --delete  # Delete dupes (one)

require_relative "../config/environment"

class ConsecutiveShipEventsWithoutDevlogFinder
  def initialize(project_identifier: nil, check_all: false, delete: false)
    @project = find_project(project_identifier) unless check_all
    @check_all = check_all
    @delete = delete
    @pairs = []
    @deleted_count = 0
    @deleted_ship_event_ids = []
  end

  def find_project(identifier)
    return nil if identifier.nil?

    project = Project.find_by(id: identifier)
    return project if project

    project = Project.where("LOWER(title) LIKE ?", "%#{identifier.downcase}%").first
    return project if project

    puts "❌ Project not found: #{identifier}"
    nil
  end

  def run
    if @check_all
      check_all_projects
    elsif @project.nil?
      puts "Usage: rails runner script/find_consecutive_ship_events_without_devlog.rb [project_id_or_title] [--delete]"
      puts "       (Run without arguments to check all projects)"
      puts "       Add --delete to remove the second ship event in each pair (the one with no devlog since previous)"
      puts "\nAvailable projects with 2+ ship events:"
      Project.joins(:ship_event_posts)
             .group("projects.id")
             .having("COUNT(posts.id) >= 2")
             .limit(10)
             .each { |p| puts "  ID: #{p.id}, Title: #{p.title}" }
      total = Project.joins(:ship_event_posts).group("projects.id").having("COUNT(posts.id) >= 2").count.size
      puts "\n... and #{total - 10} more" if total > 10
      nil
    else
      check_single_project(@project)
    end
  end

  def check_all_projects
    mode = @delete ? "🔴 DELETING" : "🔍 Finding"
    puts "#{mode} consecutive ship events with no devlog between them (all projects)...\n\n"
    puts @delete ? "⚠️  DELETION MODE: Second ship event in each pair will be deleted!" : "ℹ️  DRY-RUN: No deletions. Use --delete to remove dupes.\n\n"

    projects = Project.joins(:ship_event_posts)
                      .group("projects.id")
                      .having("COUNT(posts.id) >= 2")
                      .select("projects.*")

    total = projects.count.size
    puts "Found #{total} projects with 2+ ship events\n\n"

    projects.find_each do |project|
      check_single_project(project, silent: true)
    end

    report_all

    if @delete && @deleted_count.positive?
      puts "\n🗑️  Total ship events deleted: #{@deleted_count}"
      puts "Deleted ship event IDs: #{@deleted_ship_event_ids.join(', ')}"
    end
  end

  def check_single_project(project, silent: false)
    posts = project.ship_event_posts.reorder(created_at: :asc).to_a
    return [] if posts.size < 2

    project_pairs = []

    posts.each_cons(2) do |prev_post, next_post|
      devlog_count = project.posts
                            .of_devlogs(join: true)
                            .where("posts.created_at > ? AND posts.created_at < ?",
                                   prev_post.created_at,
                                   next_post.created_at)
                            .where(post_devlogs: { deleted_at: nil })
                            .count

      next if devlog_count.positive?

      prev_ship = prev_post.postable
      next_ship = next_post.postable
      pair = {
        project: project,
        prev_post: prev_post,
        next_post: next_post,
        prev_ship: prev_ship,
        next_ship: next_ship,
        prev_at: prev_post.created_at,
        next_at: next_post.created_at
      }
      project_pairs << pair
      @pairs << pair
    end

    unless silent
      report_single_project(project, project_pairs)
    end

    if @delete && project_pairs.any?
      delete_dupes_in_project(project, project_pairs, silent: silent)
    end

    project_pairs
  end

  def report_single_project(project, pairs)
    puts "Project: #{project.title} (ID: #{project.id})"
    puts "  Ship events: #{project.ship_event_posts.count}"
    puts "  #{@delete ? '⚠️  DELETION MODE' : 'ℹ️  DRY-RUN'}" if pairs.any?

    if pairs.empty?
      puts "  ✅ No consecutive ship events without a devlog between them.\n\n"
      return
    end

    puts "  ⚠️  Found #{pairs.size} consecutive ship event pair(s) with NO devlog between:\n\n"
    pairs.each_with_index do |pair, idx|
      print_pair(pair, idx + 1)
    end
    puts "\n"
  end

  def report_all
    if @pairs.empty?
      puts "✅ No consecutive ship events without a devlog between them (across all projects).\n"
      return
    end

    by_project = @pairs.group_by { |p| p[:project] }
    puts "=" * 60
    puts "SUMMARY"
    puts "=" * 60
    puts "Total: #{@pairs.size} consecutive ship event pair(s) with no devlog between them"
    puts "Across #{by_project.size} project(s)\n\n"

    by_project.each do |project, pairs|
      puts "📍 #{project.title} (ID: #{project.id}) – #{pairs.size} pair(s)"
      pairs.each_with_index do |pair, idx|
        print_pair(pair, idx + 1, indent: "   ")
      end
      puts "\n"
    end
  end

  def delete_dupes_in_project(project, pairs, silent: false)
    ships_to_delete = pairs.map { |p| p[:next_ship] }.uniq

    ships_to_delete.each do |ship|
      ship_id = ship.id
      post_id = ship.post&.id
      begin
        ship.destroy!
        @deleted_count += 1
        @deleted_ship_event_ids << ship_id
        puts "✅ Deleted Ship ##{ship_id} (Post ##{post_id})" unless silent
      rescue => e
        puts "❌ Error deleting Ship ##{ship_id}: #{e.message}" unless silent
      end
    end

    puts "\n🗑️  Deleted #{ships_to_delete.size} ship event(s) from this project" unless silent || ships_to_delete.empty?
  end

  def print_pair(pair, index, indent: "  ")
    prev = pair[:prev_ship]
    next_ship = pair[:next_ship]
    puts "#{indent}#{index}. Ship ##{prev.id} → Ship ##{next_ship.id}#{@delete ? " (will delete Ship ##{next_ship.id})" : ''}"
    puts "#{indent}   #{pair[:prev_at].iso8601} → #{pair[:next_at].iso8601}"
    puts "#{indent}   Gap: #{distance_of_time_in_words(pair[:prev_at], pair[:next_at])}"
    puts "#{indent}   (Post IDs: #{pair[:prev_post].id} → #{pair[:next_post].id})"
    puts ""
  end

  def distance_of_time_in_words(from, to)
    secs = (to - from).to_i
    return "0 seconds" if secs < 1

    parts = []
    [ [ 86400, "day" ], [ 3600, "hour" ], [ 60, "minute" ], [ 1, "second" ] ].each do |div, name|
      next if secs < div

      n = secs / div
      secs -= n * div
      parts << "#{n} #{name}#{'s' if n != 1}"
    end
    parts.join(", ")
  end
end

if __FILE__ == $PROGRAM_NAME
  args = ARGV.dup
  delete_mode = args.delete("--delete")
  project_identifier = args[0]
  check_all = project_identifier.nil?

  finder = ConsecutiveShipEventsWithoutDevlogFinder.new(
    project_identifier: project_identifier,
    check_all: check_all,
    delete: delete_mode
  )
  finder.run
end
