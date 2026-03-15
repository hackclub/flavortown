module Lapse
  # Resolves a user-selected timelapse ID against a list of available timelapses.
  # Returns the id and playback URL needed to enqueue the download job.
  class TimelapseResolver
    # @param timelapses [Array<Hash>, nil] available timelapse hashes (each with "id" and "playbackUrl")
    # @param timelapse_id [String, nil] the selected timelapse ID
    # @return [Hash{id: String, playback_url: String}, nil] resolved timelapse data, or nil if not found
    def self.call(timelapses:, timelapse_id:)
      return nil if timelapse_id.blank?

      timelapse = timelapses&.find { |t| t["id"] == timelapse_id }
      return nil unless timelapse

      playback_url = timelapse["playbackUrl"]
      return nil if playback_url.blank?

      { id: timelapse_id, playback_url: playback_url }
    end
  end
end
