module OgImage
  class Project < Base
    PREVIEWS = {
      "default" => -> { new(sample_project) },
      "long_title" => -> { new(sample_project(title: "This Is A Really Long Project Title That Should Wrap To Multiple Lines Nicely")) },
      "no_banner" => -> { new(sample_project(banner: false)) },
      "no_devlogs" => -> { new(sample_project(devlogs_count: 0)) }
    }.freeze

    class << self
      def sample_project(title: "floob", devlogs_count: 12, banner: true, owner: "hackclub_dev", hours: 42)
        OpenStruct.new(
          title: title,
          devlogs_count: devlogs_count,
          banner: MockAttachment.new(attached: banner),
          memberships: MockMemberships.new(owner_name: owner),
          total_hackatime_hours: hours
        )
      end
    end

    def initialize(project)
      super()
      @project = project
    end

    def render
      create_patterned_canvas

      draw_thumbnail
      draw_hack_club_flag
      draw_title
      draw_subtitle
    end

    private

    def draw_title
      lines_drawn = draw_multiline_text(
        @project.title,
        x: 80,
        y: 140,
        size: 96,
        color: "#4d3228",
        max_chars: 14,
        max_lines: 2
      )
      @title_end_y = 140 + (lines_drawn * 96 * 1.4).to_i
    end

    def draw_subtitle
      stats = build_stats
      return if stats.empty?

      start_y = @title_end_y + 20
      stats.each_with_index do |stat, index|
        draw_text(
          stat,
          x: 80,
          y: start_y + (index * 58),
          size: 48,
          color: "#5c4033"
        )
      end
    end

    def draw_thumbnail
      image_source = if @project.banner.attached?
        @project.banner
      else
        logo_path
      end

      place_image(
        image_source,
        x: 80,
        y: 115,
        width: 400,
        height: 400,
        gravity: "NorthEast",
        rounded: true,
        radius: 24
      )
    end

    def logo_path
      "https://hc-cdn.hel1.your-objectstorage.com/s/v3/288a4173f175618e_img_5401_copy.png"
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
      owner = @project.memberships.find_by(role: :owner)&.user
      stats << "by @#{owner.display_name}" if owner
      stats << "#{@project.devlogs_count} devlogs" if @project.devlogs_count.positive?
      stats << "#{hours_logged} hours worked" if hours_logged > 0
      stats
    end

    def hours_logged
      if @project.respond_to?(:total_hackatime_hours)
        @project.total_hackatime_hours.to_i
      else
        0
      end
    end
  end
end
