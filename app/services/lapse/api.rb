# The `Lapse` module encompasses most of the ways Flavortown can interact with Lapse.
# Lapse defines several API entities - the ones of note are:
#
# ### Timelapse
#   - `id: string`, the ID of the timelapse
#   - `createdAt: string`, the date when the timelapse was created.
#   - `owner: User`: Information about the owner/author of the timelapse.
#   - `comments: CommentSchema[]`: All comments for this timelapse.
#   - `playbackUrl: string?`: The public URL that can be used to stream video data. If `null`, the timelapse is still being processed.
#   - `thumbnailUrl: string?`: The URL of the thumbnail image for this timelapse. If `null`, the timelapse is still being processed. It's recommended to derive the processing status of the timelapse from `playbackUrl`.
#   - `duration: number`: The duration of the timelapse, in seconds. Must be non-negative.
#
# ### User
#   - `id: string`, the unique ID of the user.
#   - `createdAt: string`, the date when the user created their account.
#   - `handle: string`, the unique handle of the user.
#   - `displayName: string`, the display name of the user. Cannot be blank.
#   - `profilePictureUrl: string`, the profile picture URL of the user.
#   - `bio: string`, the bio of the user. Maximum of 160 characters.
#   - `urls: string[]`, featured URLs that should be displayed on the user's page. This array has a maximum of 4 members.
#   - `hackatimeId: string?`, the ID of the user in Hackatime.
#   - `slackId: string?`, the ID of the user in the Hack Club Slack. Must match the pattern `^U[A-Z0-9]+$`.
#
module Lapse
  # Wraps over Lapse's HTTP API, Hack Club's timelapse platform.
  #
  # This class only provides a subset of all of the methods that Lapse exposes!
  # See https://api.lapse.hackclub.com/docs for all endpoints.
  class Api
    # Represents the `/timelapse` endpoints of Lapse.
    class Timelapse
      # GET `/timelapse/query`
      #
      # Finds a timelapse by its ID. Returns the `data` field of https://api.lapse.hackclub.com/docs#GET/timelapse/query.
      def self.query(id)
        return nil unless Api.send(:base_url).present?

        response = Api.send(:connection).get("timelapse/query") do |req|
          req.params["id"] = id
        end

        if response.success?
          json = JSON.parse(response.body)
          return nil unless json["ok"]

          json["data"]
        else
          Rails.logger.error "Lapse::Api error (/timelapse/query): #{response.status} - #{response.body}"
          nil
        end
      end
    end

    # Represents `/hackatime` endpoints of Lapse.
    class Hackatime
      # GET `/hackatime/timelapsesForProject`
      #
      # Gets the timelapses of a given Hackatime user associated with the given Hackatime project key.
      # Returns the `data` field of https://api.lapse.hackclub.com/docs#GET/hackatime/timelapsesForProject.
      def self.timelapses_for_project(hackatime_user_id:, project_key:)
        return nil unless Api.send(:base_url).present?

        response = Api.send(:connection).get("hackatime/timelapsesForProject") do |req|
          req.params["hackatimeUserId"] = hackatime_user_id
          req.params["projectKey"] = project_key
        end

        if response.success?
          json = JSON.parse(response.body)
          return nil unless json["ok"]

          json["data"]
        else
          Rails.logger.error "Lapse::Api error (/hackatime/timelapsesForProject): #{response.status} - #{response.body}"
          nil
        end
      end
    end

    class << self
      private

      def base_url
        ENV["LAPSE_API_BASE"]
      end

      def connection
        @connection ||= Faraday.new(url: base_url) do |conn|
          conn.headers["Content-Type"] = "application/json"
          conn.headers["User-Agent"] = Rails.application.config.user_agent
        end
      end
    end
  end
end
