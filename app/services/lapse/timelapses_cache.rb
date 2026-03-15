module Lapse
  # Read/write cache layer for Lapse timelapses, keyed per project.
  class TimelapsesCache
    TTL = 10.minutes

    class << self
      # @param project_id [Integer]
      # @return [String] the cache key
      def key(project_id)
        "projects:lapse_timelapses:#{project_id}"
      end

      # @param project [Project]
      # @return [Array<Hash>, nil] cached timelapse hashes, or nil if not cached
      def read(project)
        Rails.cache.read(key(project.id))
      end

      # @param project [Project]
      # @param timelapses [Array<Hash>]
      def write(project, timelapses)
        Rails.cache.write(key(project.id), timelapses, expires_in: TTL)
      end

      # @param project [Project]
      # @return [Boolean]
      def exists?(project)
        Rails.cache.exist?(key(project.id))
      end
    end
  end
end
