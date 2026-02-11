module ProjectsHelper
  def safe(url, text = nil)
    return unless url.present? && url.start_with?("http")
    link_to(text || url, url, target: "_blank")
  end

  def format_timelapse_duration(seconds)
    return "0s" if seconds.nil? || seconds <= 0

    total_seconds = seconds.to_i
    hours = total_seconds / 3600
    minutes = (total_seconds % 3600) / 60
    secs = total_seconds % 60

    parts = []
    parts << "#{hours}hr" if hours > 0
    parts << "#{minutes}m" if minutes > 0
    parts << "#{secs}s" if hours == 0 && secs > 0

    parts.empty? ? "0s" : parts.join(" ")
  end
end
