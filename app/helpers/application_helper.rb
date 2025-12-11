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

  def achievement_icon(icon_name, earned: true, **options)
    if earned
      asset_path = find_achievement_asset(icon_name)
      if asset_path
        if asset_path.end_with?(".svg")
          inline_svg_tag(asset_path, **options)
        else
          image_tag(asset_path, **options)
        end
      else
        inline_svg_tag("icons/#{icon_name}.svg", **options)
      end
    else
      silhouette_path = AchievementSilhouettes.silhouette_path(icon_name)

      if silhouette_path && achievement_asset_exists?(silhouette_path)
        if silhouette_path.end_with?(".svg")
          inline_svg_tag(silhouette_path, **options)
        else
          image_tag(silhouette_path, **options)
        end
      else
        inline_svg_tag("icons/#{icon_name}.svg", **options.merge(style: "filter: brightness(0) opacity(0.4)"))
      end
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

  def find_achievement_asset(icon_name)
    %w[png svg jpg jpeg gif webp].each do |ext|
      path = "achievements/#{icon_name}.#{ext}"
      return path if achievement_asset_exists?(path)
    end
    nil
  end

  def achievement_asset_exists?(path)
    File.exist?(Rails.root.join("app/assets/images", path)) ||
      File.exist?(Rails.root.join("secrets/assets/images", path))
  end
end
