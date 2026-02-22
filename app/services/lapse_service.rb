class LapseService
  # Example response:
  # {
  #   "ok": true,
  #   "data": {
  #     "count": 0,
  #     "timelapses": [
  #       {
  #         "id": "string",
  #         "createdAt": 0,
  #         "owner": {
  #           "id": "string",
  #           "createdAt": 0,
  #           "handle": "string",
  #           "displayName": "string",
  #           "profilePictureUrl": "https://example.com/",
  #           "bio": "",
  #           "urls": [
  #             "https://example.com/"
  #           ],
  #           "hackatimeId": "string",
  #           "slackId": "UKCGDGWGV3D81BMMKJO709SDXV6TYZEL0BSXXMXGBGM5JVNGNGP0DY7DA6RJDG5E7VU7ODDUKPWW116ZDR56"
  #         },
  #         "name": "string",
  #         "description": "",
  #         "comments": [
  #           {
  #             "id": "string",
  #             "content": "string",
  #             "author": {
  #               "id": "string",
  #               "createdAt": 0,
  #               "handle": "string",
  #               "displayName": "string",
  #               "profilePictureUrl": "https://example.com/",
  #               "bio": "",
  #               "urls": [
  #                 "https://example.com/"
  #               ],
  #               "hackatimeId": "string",
  #               "slackId": "UAHYSXDRMAKO9033E3R2TM9BS9UE5XM08BUBS67DXTV38ILEKAY1S7E7CXD0VMOP3X12EMJ2IV6E1QUDWA08LBM5Q"
  #             },
  #             "createdAt": 0
  #           }
  #         ],
  #         "visibility": "UNLISTED",
  #         "isPublished": true,
  #         "playbackUrl": "https://example.com/",
  #         "thumbnailUrl": "https://example.com/",
  #         "videoContainerKind": "WEBM",
  #         "duration": 0,
  #         "private": {
  #           "device": {
  #             "id": "ffffffff-ffff-ffff-ffff-ffffffffffff",
  #             "name": "string"
  #           },
  #           "hackatimeProject": "string"
  #         }
  #       }
  #     ]
  #   }
  # }
  def self.fetch_timelapses_for_project(hackatime_user_id:, project_key:)
    unless base_url.present?
      return nil
    end

    response = connection.get("hackatime/timelapsesForProject") do |req|
      req.params["hackatimeUserId"] = hackatime_user_id
      req.params["projectKey"] = project_key
    end

    if response.success?
      data = JSON.parse(response.body)
      return nil unless data["ok"]

      data.dig("data", "timelapses") || []
    else
      Rails.logger.error "LapseService error: #{response.status} - #{response.body}"
      nil
    end
  rescue => e
    Rails.logger.error "LapseService exception: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    nil
  end

  def self.fetch_all_timelapses_for_projects(hackatime_user_id:, project_keys:)
    timelapses = []

    project_keys.each do |project_key|
      result = fetch_timelapses_for_project(
        hackatime_user_id: hackatime_user_id,
        project_key: project_key
      )
      timelapses.concat(result) if result.present?
    end

    timelapses
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
