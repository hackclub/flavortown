module ApplicationHelper
  def admin_tool(&block)
    if current_user&.admin?
      content_tag(:div, class: "admin tools-do", &block)
    end
  end

  def format_seconds(seconds, include_days: false)
    return "0s" if seconds.nil? || seconds <= 0

    days = seconds / 86400
    hours = (seconds % 86400) / 3600
    minutes = (seconds % 3600) / 60
    secs = seconds % 60

    parts = []
    parts << "#{days}d" if include_days && days > 0
    parts << "#{hours}h" if hours > 0 || (include_days && days > 0)
    parts << "#{minutes}m" if minutes > 0 || parts.any?
    parts << "#{secs}s" if parts.empty?

    parts.join(" ")
  end

  def dev_tool(&block)
    if Rails.env.development?
      content_tag(:div, class: "dev tools-do", &block)
    end
  end
  def random_carousel_transform
    "rotate(#{rand(-3..3)}deg) scale(#{(rand(97..103).to_f / 100).round(2)}) translateY(#{rand(-8..8)}px)"
  end

  def safe_external_url(url)
    return nil if url.blank?

    uri = URI.parse(url)
    uri.scheme&.downcase.in?(%w[http https]) ? url : nil
  rescue URI::InvalidURIError
    nil
  end
end
