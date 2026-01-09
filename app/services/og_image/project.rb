module OgImage
  class Project < Base
    PREVIEWS = {
      "default" => -> { new(sample_project) },
      "long_title" => -> { new(sample_project(title: "This Is A Really Long Project Title That Should Wrap To Multiple Lines Nicely")) },
      "no_banner" => -> { new(sample_project(banner: false)) },
      "no_devlogs" => -> { new(sample_project(devlogs_count: 0)) }
    }.freeze

    class << self
      def sample_project(title: "My Awesome Project", devlogs_count: 12, banner: true, owner: "hackclub_dev")
        OpenStruct.new(
          title: title,
          devlogs_count: devlogs_count,
          banner: MockAttachment.new(attached: banner),
          memberships: MockMemberships.new(owner_name: owner)
        )
      end
    end

    def initialize(project)
      super()
      @project = project
    end

    def render
      create_canvas

      draw_title
      draw_subtitle
      draw_branding
      draw_thumbnail if @project.banner.attached?
    end

    private

    def draw_title
      draw_multiline_text(
        @project.title,
        x: 60,
        y: 180,
        size: 52,
        color: "#ffffff",
        max_chars: 30,
        max_lines: 3
      )
    end

    def draw_subtitle
      subtitle = build_subtitle
      return if subtitle.blank?

      draw_text(
        truncate_text(subtitle, 50),
        x: 60,
        y: 420,
        size: 28,
        color: "#aaaaaa"
      )
    end

    def draw_branding
      draw_text(
        "flavortown.hackclub.com",
        x: 60,
        y: 50,
        size: 24,
        color: "#666666",
        gravity: "SouthWest"
      )
    end

    def draw_thumbnail
      place_image(
        @project.banner,
        x: 60,
        y: 0,
        width: 400,
        height: 400,
        gravity: "East"
      )
    end

    def build_subtitle
      owner = @project.memberships.find_by(role: :owner)&.user
      parts = []
      parts << "by #{owner.display_name}" if owner
      parts << "#{@project.devlogs_count} devlogs" if @project.devlogs_count.positive?
      parts.join(" · ")
    end
  end
end
