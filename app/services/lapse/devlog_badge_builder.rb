module Lapse
  # Determines which devlogs should display a "Tracked with Lapse" badge.
  # A devlog gets a badge if any timelapse was created between it and the previous devlog
  # (or the project creation time for the first devlog).
  class DevlogBadgeBuilder
    # @param project [Project] the project (used for created_at as the initial time boundary)
    # @param devlog_posts [Array<Post>] devlog posts (must have .postable_id and .created_at)
    # @param timelapses [Array<Hash>, nil] timelapse hashes from the Lapse API (each with "createdAt" in ms)
    def initialize(project:, devlog_posts:, timelapses:)
      @project = project
      @devlog_posts = devlog_posts
      @timelapses = timelapses
    end

    # @return [Hash{Integer => Boolean}] map of devlog postable_id to whether it should show a lapse badge
    def call
      return {} if @devlog_posts.blank? || @timelapses.blank?

      timelapse_times = @timelapses.filter_map do |timelapse|
        created_at_ms = timelapse["createdAt"]
        next if created_at_ms.blank?

        Time.at(created_at_ms.to_i / 1000.0)
      rescue ArgumentError, TypeError
        nil
      end.sort

      return {} if timelapse_times.blank?

      badges = {}
      previous_time = @project.created_at
      @devlog_posts.sort_by(&:created_at).each do |devlog_post|
        current_time = devlog_post.created_at
        badges[devlog_post.postable_id] = timelapse_times.any? { |time| time > previous_time && time <= current_time }
        previous_time = current_time
      end

      badges
    end
  end
end
