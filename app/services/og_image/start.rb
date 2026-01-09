module OgImage
  class Start < Base
    PREVIEWS = {
      "default" => -> { new }
    }.freeze

    def render
      welcome_path = Rails.root.join("app", "assets", "images", "welcome.png").to_s
      @image = MiniMagick::Image.open(welcome_path)
      @image.resize("#{WIDTH}x#{HEIGHT}!")
    end
  end
end
