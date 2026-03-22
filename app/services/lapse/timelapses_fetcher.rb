module Lapse
  # Fetches timelapses from the Lapse API for a given project.
  # Handles guard checks (env, hackatime keys, user identity), optional time filtering,
  # and a per-project Redis cache layer (transparent to callers).
  class TimelapsesFetcher
    CACHE_TTL = 10.minutes

    # @param project [Project] the project to fetch timelapses for
    # @param user [User, nil] optional user whose Hackatime identity to use (falls back to project owner)
    # @param since [ActiveSupport::TimeWithZone, nil] if set, bypass cache and only return timelapses created after this time
    def initialize(project:, user: nil, since: nil)
      @project = project
      @user = user
      @since = since
    end

    # @return [Boolean] whether all prerequisites are met to fetch timelapses
    def fetchable?
      ENV["LAPSE_API_BASE"].present? &&
        @project.hackatime_keys.present? &&
        hackatime_user_id.present?
    end

    # Fetches timelapses, using the cache when possible.
    # When +since+ is set the cache is bypassed (filtered results shouldn't populate the full-project cache).
    # @return [Array<Hash>] timelapse hashes sorted by createdAt descending, or [] on failure
    def call
      return [] unless fetchable?

      return fetch_from_api if @since.present?

      cached = self.class.cache_read(@project)
      return cached if cached

      timelapses = fetch_from_api
      self.class.cache_write(@project, timelapses)
      timelapses
    end

    # Returns cached timelapses without hitting the API.
    # @param project [Project]
    # @return [Array<Hash>, nil] cached timelapse hashes, or nil if not cached
    def self.cached(project)
      cache_read(project)
    end

    private

    def fetch_from_api
      timelapses = []
      @project.hackatime_keys.each do |project_key|
        result = Lapse::Api::Hackatime.timelapses_for_project(
          hackatime_user_id: hackatime_user_id,
          project_key: project_key
        )

        timelapses.concat(result["timelapses"]) if result.present?
      end

      timelapses = filter_since(timelapses) if @since.present?
      timelapses.sort_by { |t| -(t["createdAt"] || 0) }
    rescue StandardError => e
      Rails.logger.error "Lapse::TimelapsesFetcher error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      []
    end

    def self.cache_key(project_id)
      "projects:lapse_timelapses:#{project_id}"
    end

    def self.cache_read(project)
      Rails.cache.read(cache_key(project.id))
    end

    def self.cache_write(project, timelapses)
      Rails.cache.write(cache_key(project.id), timelapses, expires_in: CACHE_TTL)
    end

    def hackatime_user_id
      @hackatime_user_id ||= (@user || @project.memberships.owner.first&.user)&.hackatime_identity&.uid
    end

    def filter_since(timelapses)
      timelapses.select do |timelapse|
        created_at = Time.at(timelapse["createdAt"].to_i / 1000.0) rescue nil
        created_at && created_at > @since
      end
    end
  end
end
