module Lapse
  # Fetches timelapses from the Lapse API for a given project.
  # Handles guard checks (env, hackatime keys, user identity) and optional time filtering.
  class TimelapsesFetcher
    # @param project [Project] the project to fetch timelapses for
    # @param user [User, nil] optional user whose Hackatime identity to use (falls back to project owner)
    # @param since [ActiveSupport::TimeWithZone, nil] if set, only return timelapses created after this time
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

    # @return [Array<Hash>] timelapse hashes sorted by createdAt descending, or [] on failure
    def call
      Rails.logger.info "is fetchable: #{fetchable?}, project_id: #{@project.id}, hackatime_user_id: #{hackatime_user_id}, since: #{@since}"
      return [] unless fetchable?

      timelapses = []
      @project.hackatime_keys.each do |project_key|
        Rails.logger.info "Fetching timelapses for project #{@project.id} with hackatime key #{project_key}"
        result = Lapse::Api::Hackatime::timelapses_for_project(
          hackatime_user_id: hackatime_user_id,
          project_key: project_key
        )

        timelapses.concat(result["timelapses"]) if result.present?
      end
      
      Rails.logger.info "Fetched #{timelapses.size} timelapses for project #{@project.id} before filtering"

      timelapses = filter_since(timelapses) if @since.present?

      Rails.logger.info "Returning #{timelapses.size} timelapses for project #{@project.id} after filtering since #{@since}"

      timelapses.sort_by { |t| -(t["createdAt"] || 0) }
    rescue StandardError => e
      Rails.logger.error "Lapse::TimelapsesFetcher error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      []
    end

    private

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
