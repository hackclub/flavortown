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

  def achievement_icon(icon_name, **options)
    png_path = "achievements/#{icon_name}.png"
    svg_path = "achievements/#{icon_name}.svg"

    if asset_exists?(png_path)
      image_tag(png_path, **options)
    elsif asset_exists?(svg_path)
      inline_svg_tag(svg_path, **options)
    else
      inline_svg_tag("icons/#{icon_name}.svg", **options)
    end
  end


  def cache_stats
    hits = Thread.current[:cache_hits] || 0
    misses = Thread.current[:cache_misses] || 0
    { hits: hits, misses: misses }
  end

  def requests_per_second
    rps = RequestCounter.per_second
    rps == :high_load ? "lots of req/sec" : "#{rps} req/sec"
  end

  private

  def asset_exists?(path)
    File.exist?(Rails.root.join("app/assets/images", path))
  end
end
