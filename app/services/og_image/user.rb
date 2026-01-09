module OgImage
  class MockUser
    def initialize(display_name:, projects_count:, cookies_earned:, hours_logged:, joined_at: nil)
      @display_name = display_name
      @projects_count = projects_count
      @cookies_earned = cookies_earned
      @hours_logged = hours_logged
      @created_at = joined_at || 3.months.ago
    end

    attr_reader :display_name, :projects_count, :cookies_earned, :hours_logged, :created_at

    def avatar
      MockAvatar.new
    end

    def balance
      @cookies_earned
    end

    def devlog_seconds_total
      @hours_logged * 3600
    end
  end

  class MockAvatar
    def attached?
      true
    end

    def download
      require "open-uri"
      URI.open("https://placecats.com/400/400").read
    rescue StandardError
      path = Rails.root.join("tmp", "mock_avatar_#{SecureRandom.hex(4)}.png").to_s
      MiniMagick::Tool.new("convert") do |convert|
        convert.size("400x400")
        convert << "xc:#e8d5b7"
        convert << path
      end
      data = File.binread(path)
      FileUtils.rm_f(path)
      data
    end
  end

  class User < Base
    PREVIEWS = {
      "default" => -> { new(sample_user) },
      "new_user" => -> { new(sample_user(display_name: "New Member", projects_count: 0, cookies_earned: 0, hours_logged: 0)) },
      "prolific" => -> { new(sample_user(display_name: "Super Builder", projects_count: 50, cookies_earned: 2500, hours_logged: 150)) }
    }.freeze

    class << self
      def sample_user(display_name: "hackclub_dev", projects_count: 5, cookies_earned: 350, hours_logged: 42)
        MockUser.new(
          display_name: display_name,
          projects_count: projects_count,
          cookies_earned: cookies_earned,
          hours_logged: hours_logged
        )
      end
    end

    def initialize(user)
      super()
      @user = user
    end

    def render
      create_patterned_canvas

      draw_avatar
      draw_hack_club_flag
      draw_title
      draw_subtitle
    end

    private

    def draw_title
      lines_drawn = draw_multiline_text(
        "@#{@user.display_name}",
        x: 80,
        y: 115,
        size: 86,
        color: "#4d3228",
        max_chars: 14,
        max_lines: 2
      )
      @title_end_y = 115 + (lines_drawn * 86 * 1.3).to_i
    end

    def draw_subtitle
      stats = build_stats
      return if stats.empty?

      start_y = @title_end_y + 10
      stats.each_with_index do |stat, index|
        draw_text(
          stat,
          x: 80,
          y: start_y + (index * 42),
          size: 34,
          color: "#5c4033"
        )
      end
    end

    def draw_avatar
      place_image(
        @user.avatar,
        x: 80,
        y: 115,
        width: 400,
        height: 400,
        gravity: "NorthEast",
        rounded: true,
        radius: 24
      )
    end

    def draw_hack_club_flag
      place_image(
        "https://assets.hackclub.com/flag-orpheus-top.png",
        x: 20,
        y: 0,
        width: 300,
        height: 360,
        gravity: "NorthWest",
        cover: false
      )
    end

    def build_stats
      stats = []
      stats << "#{projects_count} projects" if projects_count > 0
      stats << "#{cookies_earned} cookies earned" if cookies_earned > 0
      stats << "#{hours_logged} hours worked" if hours_logged > 0
      stats << "Joined #{joined_ago}"
      stats
    end

    def joined_ago
      return "recently" unless @user.respond_to?(:created_at) && @user.created_at

      ActionController::Base.helpers.time_ago_in_words(@user.created_at) + " ago"
    end

    def projects_count
      @user.respond_to?(:projects_count) ? (@user.projects_count || 0) : 0
    end

    def cookies_earned
      if @user.respond_to?(:balance)
        @user.balance.to_i
      elsif @user.respond_to?(:cookies_earned)
        @user.cookies_earned.to_i
      else
        0
      end
    end

    def hours_logged
      if @user.respond_to?(:devlog_seconds_total)
        (@user.devlog_seconds_total / 3600.0).round
      elsif @user.respond_to?(:hours_logged)
        @user.hours_logged.to_i
      else
        0
      end
    end
  end
end
