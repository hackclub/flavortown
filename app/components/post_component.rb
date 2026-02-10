# frozen_string_literal: true

class PostComponent < ViewComponent::Base
  with_collection_parameter :post

  attr_reader :post, :compact

  def initialize(post:, current_user: nil, theme: nil, compact: false)
    @post = post
    @current_user = current_user
    @theme = theme
    @compact = compact
  end

  def compact?
    @compact
  end

  def variant
    @variant ||= case postable
    when Post::ShipEvent then :ship
    when Post::FireEvent then :fire
    when Post::GitCommit then :git_commit
    when Post::Devlog    then :devlog
    else nil
    end
  end

  def postable
    @postable ||= post.postable
  end

  def project_title
    if post.project&.title.present?
      post.project&.title
    end
  end

  def author_name
    post.user&.display_name.presence || "System"
  end

  def posted_at_text
    helpers.time_ago_in_words(post.created_at)
  end

  def duration_text
    return nil unless postable.respond_to?(:duration_seconds)

    seconds = postable.duration_seconds.to_i
    return nil if seconds.zero?

    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    "#{hours}h #{minutes}m"
  end

  def ship_event?
    postable.is_a?(Post::ShipEvent)
  end

  def unapproved_ship_event?
    ship_event? && postable.certification_status != "approved"
  end

  def ship_event_has_payout?
    ship_event? && postable.payout.present?
  end

  def show_ship_event_payout_footer?
    return false unless ship_event?
    return true if @current_user&.admin?
    postable.payout.present?
  end

  def estimated_payout_data
    return nil unless ship_event?

    hours = postable.hours&.to_f
    percentile = postable.overall_percentile

    return { hours: hours, cookies: nil, multiplier: nil } if hours.nil? || percentile.nil?

    game_constants = Rails.configuration.game_constants
    low = game_constants.lowest_dollar_per_hour.to_f
    high = game_constants.highest_dollar_per_hour.to_f
    tickets_per_dollar = game_constants.tickets_per_dollar.to_f

    p = (percentile.to_f / 100.0).clamp(0.0, 1.0)
    gamma = 1.745427173
    hourly_rate = low + (high - low) * (p ** gamma)
    hourly_rate = hourly_rate.clamp(low, high)

    cookies = (hours * hourly_rate * tickets_per_dollar).round
    multiplier = (hourly_rate * tickets_per_dollar).round(2)

    { hours: hours.round(2), cookies: cookies, multiplier: multiplier }
  end

  def devlog?
    postable.is_a?(Post::Devlog)
  end

  def fire_event?
    postable.is_a?(Post::FireEvent)
  end

  def git_commit?
    postable.is_a?(Post::GitCommit)
  end

  def author_activity
    if fire_event?
      "sent their compliments to the chef of"
    elsif ship_event?
      "shipped"
    elsif git_commit?
      "committed to"
    else
      "worked on"
    end
  end

  def attachments
    return [] unless postable.respond_to?(:attachments)

    seen_filenames = Set.new
    postable.attachments.select do |att|
      filename = att.filename.to_s
      if seen_filenames.include?(filename)
        false
      else
        seen_filenames.add(filename)
        true
      end
    end
  end

  def scrapbook_url
    return nil unless postable.respond_to?(:scrapbook_url)
    postable.scrapbook_url
  end

  def image?(attachment)
    attachment.content_type.start_with?("image/")
  end

  def gif?(attachment)
    attachment.content_type == "image/gif"
  end

  def video?(attachment)
    attachment.content_type.start_with?("video/")
  end

  def variant_class
    "post--#{variant}"
  end

  def commentable
    postable
  end

  def can_edit?
    devlog? && @current_user.present? && post.user == @current_user && !deleted?
  end

  def can_force_delete?
    devlog? && @current_user.present? && !deleted? &&
      (@current_user.admin? || @current_user.has_role?(:fraud_dept))
  end

  def project_shipped?
    post.project&.shipped?
  end

  def deleted?
    devlog? && postable.deleted?
  end

  def can_see_deleted?
    @current_user&.can_see_deleted_devlogs?
  end

  def edit_devlog_path
    return nil unless can_edit?
    return nil unless post.project.present?
    helpers.edit_project_devlog_path(post.project, postable)
  end

  def delete_devlog_path
    return nil unless can_edit?
    return nil unless post.project.present?
    helpers.project_devlog_path(post.project, postable)
  end

  def force_delete_devlog_path
    return nil unless can_force_delete?
    return nil unless post.project.present?
    helpers.project_devlog_path(post.project, postable, force: true)
  end

  def theme_class
    return nil unless @theme = :explore_mixed

    themes = %i[devlog ship fire certified]
    picked = themes[post.id.to_i % themes.length]
    "post--theme-#{picked}"
  end
end
